import Map "mo:core/Map";
import Set "mo:core/Set";
import Iter "mo:core/Iter";
import Array "mo:core/Array";
import Text "mo:core/Text";
import List "mo:core/List";
import Principal "mo:core/Principal";
import Time "mo:core/Time";
import Runtime "mo:core/Runtime";
import Nat "mo:core/Nat";
import Order "mo:core/Order";
import MixinAuthorization "authorization/MixinAuthorization";
import AccessControl "authorization/access-control";

actor {
  /// Custom Types & Comparisons
  type UserProfile = {
    name : Text;
    email : Text;
    role : AccessControl.UserRole;
    grade : ?Text;
    subject : ?Text;
  };

  module UserProfile {
    public func compare(profile1 : UserProfile, profile2 : UserProfile) : Order.Order {
      switch (Text.compare(profile1.name, profile2.name)) {
        case (#equal) { Text.compare(profile1.email, profile2.email) };
        case (order) { order };
      };
    };
  };

  type FeeStatus = {
    student : Principal;
    amount : Nat;
    paid : Bool;
  };

  module FeeStatus {
    public func compare(fee1 : FeeStatus, fee2 : FeeStatus) : Order.Order {
      if (fee1.amount < fee2.amount) {
        #less;
      } else if (fee1.amount > fee2.amount) {
        #greater;
      } else {
        Text.compare(fee1.student.toText(), fee2.student.toText());
      };
    };
  };

  type TimetableEntry = {
    grade : Text;
    subject : Text;
    day : Text;
    time : Text;
  };

  module TimetableEntry {
    public func compare(entry1 : TimetableEntry, entry2 : TimetableEntry) : Order.Order {
      switch (Text.compare(entry1.grade, entry2.grade)) {
        case (#equal) { Text.compare(entry1.subject, entry2.subject) };
        case (order) { order };
      };
    };
  };

  type SubjectAssignment = {
    teacher : Principal;
    subject : Text;
  };

  type Grade = {
    subject : Text;
    score : Nat;
  };

  module Grade {
    public func compare(grade1 : Grade, grade2 : Grade) : Order.Order {
      if (grade1.score < grade2.score) {
        #less;
      } else if (grade1.score > grade2.score) {
        #greater;
      } else {
        Text.compare(grade1.subject, grade2.subject);
      };
    };
  };

  type ContactForm = {
    name : Text;
    email : Text;
    message : Text;
    timestamp : Time.Time;
  };

  module ContactForm {
    public func compare(form1 : ContactForm, form2 : ContactForm) : Order.Order {
      if (form1.timestamp < form2.timestamp) { #less } else {
        if (form1.timestamp > form2.timestamp) { #greater } else {
          Text.compare(form1.email, form2.email);
        };
      };
    };
  };

  type PasswordResetToken = {
    token : Text;
    user : Principal;
    expiration : Time.Time;
    used : Bool;
  };

  module PasswordResetToken {
    public func compare(token1 : PasswordResetToken, token2 : PasswordResetToken) : Order.Order {
      if (token1.expiration < token2.expiration) {
        #less;
      } else if (token1.expiration > token2.expiration) {
        #greater;
      } else {
        Text.compare(token1.token, token2.token);
      };
    };
  };

  /// State Variables
  let accessControlState = AccessControl.initState();
  include MixinAuthorization(accessControlState);

  let userProfiles = Map.empty<Principal, UserProfile>();
  let feeStatuses = Map.empty<Principal, FeeStatus>();
  let timetableEntries = List.empty<TimetableEntry>();
  let subjectAssignments = List.empty<SubjectAssignment>();
  let studentGrades = Map.empty<Principal, List.List<Grade>>();
  let contactForms = List.empty<ContactForm>();
  let passwordResetTokens = Set.empty<Text>();

  let passwordResetTokenMap = Map.empty<Text, PasswordResetToken>();

  /// Helper function to check if user is a teacher
  func isTeacher(user : Principal) : Bool {
    switch (userProfiles.get(user)) {
      case (null) { false };
      case (?profile) {
        switch (profile.role) {
          case (#admin) { true };
          case (#user) {
            // Check if user profile has subject field (indicates teacher)
            switch (profile.subject) {
              case (null) { false };
              case (?_) { true };
            };
          };
          case (#guest) { false };
        };
      };
    };
  };

  /// Helper function to check if user is a student
  func isStudent(user : Principal) : Bool {
    switch (userProfiles.get(user)) {
      case (null) { false };
      case (?profile) {
        switch (profile.role) {
          case (#admin) { false };
          case (#user) {
            // Check if user profile has grade field (indicates student)
            switch (profile.grade) {
              case (null) { false };
              case (?_) { true };
            };
          };
          case (#guest) { false };
        };
      };
    };
  };

  /// User Profile Management
  public query ({ caller }) func getCallerUserProfile() : async ?UserProfile {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only users can save profiles");
    };
    userProfiles.get(caller);
  };

  public query ({ caller }) func getUserProfile(user : Principal) : async ?UserProfile {
    if (caller != user and not AccessControl.isAdmin(accessControlState, caller)) {
      Runtime.trap("Unauthorized: Can only view your own profile");
    };
    userProfiles.get(user);
  };

  public shared ({ caller }) func saveCallerUserProfile(profile : UserProfile) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only users can save profiles");
    };
    userProfiles.add(caller, profile);
  };

  /// Fee Management
  public shared ({ caller }) func setFeeStatus(student : Principal, amount : Nat, paid : Bool) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can set fee status");
    };
    let feeStatus : FeeStatus = {
      student;
      amount;
      paid;
    };
    feeStatuses.add(student, feeStatus);
  };

  public query ({ caller }) func getAllFees() : async [FeeStatus] {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can view all fees");
    };
    feeStatuses.values().toArray().sort();
  };

  public query ({ caller }) func getStudentFees(student : Principal) : async FeeStatus {
    // Student can view own fees, admin can view any
    if (caller != student and not AccessControl.isAdmin(accessControlState, caller)) {
      Runtime.trap("Unauthorized: Can only view your own fees");
    };
    switch (feeStatuses.get(student)) {
      case (null) { Runtime.trap("Student does not exist") };
      case (?fee) { fee };
    };
  };

  /// Timetable Management
  public shared ({ caller }) func addTimetableEntry(grade : Text, subject : Text, day : Text, time : Text) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can add timetable entries");
    };
    let entry : TimetableEntry = {
      grade;
      subject;
      day;
      time;
    };
    timetableEntries.add(entry);
  };

  public query ({ caller }) func getTimetableForGrade(grade : Text) : async [TimetableEntry] {
    // Authenticated users (students/teachers) can view timetables
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can view timetables");
    };
    let filteredEntries = timetableEntries.values().filter(
      func(e) { e.grade == grade }
    );
    filteredEntries.toArray().sort();
  };

  /// Subject Assignment Management
  public shared ({ caller }) func addSubjectAssignment(teacher : Principal, subject : Text) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can add subject assignments");
    };
    let assignment : SubjectAssignment = {
      teacher;
      subject;
    };
    subjectAssignments.add(assignment);
  };

  public query ({ caller }) func getSubjectsForTeacher(teacher : Principal) : async [Text] {
    // Teacher can view own subjects, admin can view any
    if (caller != teacher and not AccessControl.isAdmin(accessControlState, caller)) {
      Runtime.trap("Unauthorized: Can only view your own subject assignments");
    };
    let filteredAssignments = subjectAssignments.values().filter(
      func(a) { a.teacher == teacher }
    );
    filteredAssignments.toArray().map(func(a) { a.subject });
  };

  /// Grades Management
  public shared ({ caller }) func addGrade(student : Principal, subject : Text, score : Nat) : async () {
    // Only teachers (users with subject field) or admins can add grades
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can add grades");
    };
    if (not (isTeacher(caller) or AccessControl.isAdmin(accessControlState, caller))) {
      Runtime.trap("Unauthorized: Only teachers can add grades");
    };
    let grade : Grade = {
      subject;
      score;
    };
    switch (studentGrades.get(student)) {
      case (null) {
        let newGrades = List.empty<Grade>();
        newGrades.add(grade);
        studentGrades.add(student, newGrades);
      };
      case (?grades) {
        grades.add(grade);
      };
    };
  };

  public query ({ caller }) func getGrades(student : Principal) : async [Grade] {
    // Student can view own grades, teachers and admins can view any
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only authenticated users can view grades");
    };
    if (caller != student and not (isTeacher(caller) or AccessControl.isAdmin(accessControlState, caller))) {
      Runtime.trap("Unauthorized: Can only view your own grades");
    };
    switch (studentGrades.get(student)) {
      case (null) { [] };
      case (?grades) { grades.toArray().sort() };
    };
  };

  /// Contact Form Management
  public shared ({ caller }) func submitContactForm(name : Text, email : Text, message : Text) : async () {
    // Anyone can submit contact forms (including guests)
    let form : ContactForm = {
      name;
      email;
      message;
      timestamp = Time.now();
    };
    contactForms.add(form);
  };

  public query ({ caller }) func getAllContactForms() : async [ContactForm] {
    // Only admins can view all contact forms
    if (not (AccessControl.hasPermission(accessControlState, caller, #admin))) {
      Runtime.trap("Unauthorized: Only admins can view contact forms");
    };
    let contactFormsList = contactForms.toArray();
    contactFormsList.sort();
  };

  /// Password Reset Management
  public shared ({ caller }) func generatePasswordResetToken(user : Principal) : async Text {
    // Anyone can request password reset (including guests)
    let token = Time.now().toText();
    passwordResetTokens.add(token);
    let resetToken : PasswordResetToken = {
      token;
      user;
      expiration = Time.now() + 3600 * 1000000000;
      used = false;
    };
    passwordResetTokenMap.add(token, resetToken);
    token;
  };

  public shared ({ caller }) func verifyPasswordResetToken(token : Text) : async Bool {
    // Anyone can verify password reset tokens (including guests)
    switch (passwordResetTokenMap.get(token)) {
      case (null) { Runtime.trap("Invalid token!") };
      case (?resetToken) {
        if (resetToken.used or Time.now() > resetToken.expiration) {
          false;
        } else {
          let newToken : PasswordResetToken = {
            token;
            user = resetToken.user;
            expiration = resetToken.expiration;
            used = true;
          };
          passwordResetTokenMap.add(token, newToken);
          true;
        };
      };
    };
  };

  public query ({ caller }) func isTokenValid(token : Text) : async Bool {
    // Anyone can check token validity (including guests)
    passwordResetTokens.contains(token);
  };
};
