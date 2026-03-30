import type { Principal } from "@icp-sdk/core/principal";
export interface Some<T> {
    __kind__: "Some";
    value: T;
}
export interface None {
    __kind__: "None";
}
export type Option<T> = Some<T> | None;
export interface Grade {
    subject: string;
    score: bigint;
}
export type Time = bigint;
export interface ContactForm {
    name: string;
    email: string;
    message: string;
    timestamp: Time;
}
export interface TimetableEntry {
    day: string;
    subject: string;
    time: string;
    grade: string;
}
export interface FeeStatus {
    paid: boolean;
    student: Principal;
    amount: bigint;
}
export interface UserProfile {
    subject?: string;
    name: string;
    role: UserRole;
    email: string;
    grade?: string;
}
export enum UserRole {
    admin = "admin",
    user = "user",
    guest = "guest"
}
export interface backendInterface {
    /**
     * / Grades Management
     */
    addGrade(student: Principal, subject: string, score: bigint): Promise<void>;
    /**
     * / Subject Assignment Management
     */
    addSubjectAssignment(teacher: Principal, subject: string): Promise<void>;
    /**
     * / Timetable Management
     */
    addTimetableEntry(grade: string, subject: string, day: string, time: string): Promise<void>;
    assignCallerUserRole(user: Principal, role: UserRole): Promise<void>;
    /**
     * / Password Reset Management
     */
    generatePasswordResetToken(user: Principal): Promise<string>;
    getAllContactForms(): Promise<Array<ContactForm>>;
    getAllFees(): Promise<Array<FeeStatus>>;
    /**
     * / User Profile Management
     */
    getCallerUserProfile(): Promise<UserProfile | null>;
    getCallerUserRole(): Promise<UserRole>;
    getGrades(student: Principal): Promise<Array<Grade>>;
    getStudentFees(student: Principal): Promise<FeeStatus>;
    getSubjectsForTeacher(teacher: Principal): Promise<Array<string>>;
    getTimetableForGrade(grade: string): Promise<Array<TimetableEntry>>;
    getUserProfile(user: Principal): Promise<UserProfile | null>;
    isCallerAdmin(): Promise<boolean>;
    isTokenValid(token: string): Promise<boolean>;
    saveCallerUserProfile(profile: UserProfile): Promise<void>;
    /**
     * / Fee Management
     */
    setFeeStatus(student: Principal, amount: bigint, paid: boolean): Promise<void>;
    /**
     * / Contact Form Management
     */
    submitContactForm(name: string, email: string, message: string): Promise<void>;
    verifyPasswordResetToken(token: string): Promise<boolean>;
}
