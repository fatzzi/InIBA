# InIBA — Use-Case View

*Team Markzingerburger*

## 1. Overview

This document describes the use-case view of the InIBA system: an IBA-exclusive, BeReal-inspired mobile app that gives verified students one place for low-pressure social content and structured campus updates. It covers the four core features of the proposal (Login/Authentication, Search & Filter, User Profile, and Content Creation) as a set of actors and use cases.

## 2. Actors

InIBA has one primary human actor and three supporting system actors:

- **Student** (primary): A verified IBA student, authenticated with an `@khi.iba.edu.pk` email address. Logs in, browses and filters the feed, searches for other students, manages their profile, and creates posts.
- **Email / OTP Service** (external): Sends the one-time passcode used to confirm that a signing-up student has active access to their university inbox.
- **Push Notification Service** (external): Delivers the randomly-timed "IBA Moment" push notification that opens the daily content-creation window.
- **Content Moderation Service** (external): Automated NSFW / inappropriate-content filter that screens every uploaded image before it can be published to the feed.

## 3. Use-Case Diagram

The use-case diagram groups use cases under the InIBA System boundary, connected to the Student actor and the three external system actors (Push Notification Service, Email / OTP Service, Development Team), including `<<include>>` relationships (e.g. Sign Up includes Verify Email (OTP); Create Post includes Capture Photo) and `<<extend>>` relationships (e.g. Tag Location extends Create Post).

*(Original diagram image not included in this repo — see project design files.)*

## 4. Use-Case Descriptions

### 4.1 Authentication

#### 4.1.1 Sign Up

- **Includes:** Verify Email (OTP)
- **Actors:** Student
- **Brief Description:** Allows a new student to register for InIBA using their university email address.
- **Precondition:** The user does not already have an InIBA account and is at the Welcome Screen.
- **Main Flow:**
  1. Student selects "Sign Up" from the Welcome Screen.
  2. Student enters their university email, a password, and a password confirmation.
  3. System validates that the email ends in `@khi.iba.edu.pk`.
  4. Student submits the form; the app calls the `/auth/register` endpoint.
  5. System creates a pending account and triggers Verify Email (OTP).
- **Postcondition:** A pending, unverified account exists and an OTP has been sent to the student's email.
- **Exception:** If the email does not match the university domain, the system rejects the submission and shows an error.

#### 4.1.2 Verify Email (OTP)

- **Included by:** Sign Up
- **Actors:** Student, Email / OTP Service
- **Brief Description:** Confirms that the student has active access to the university inbox they registered with.
- **Precondition:** Sign Up has been submitted and an OTP has been generated.
- **Main Flow:**
  1. System, via the Email / OTP Service, sends a 6-digit one-time code to the student's university email.
  2. Student opens their email client and retrieves the code.
  3. Student enters the 6-digit code on the OTP Verification screen.
  4. App sends the code and email to `/auth/verify`.
  5. System validates the code and, if correct, issues a JWT.
  6. App securely stores the JWT and redirects the student to the Main Feed / Profile Setup.
- **Postcondition:** The account is verified and active; the student is authenticated.
- **Exception:** If the code is incorrect or expired, the system shows an error and lets the student request a new code.

#### 4.1.3 Log In

- **Actors:** Student
- **Brief Description:** Allows an already-verified student to authenticate into an existing account.
- **Precondition:** The student has a verified InIBA account and is not currently logged in.
- **Main Flow:**
  1. On app launch, the system checks secure storage for an existing JWT.
  2. If no valid token is found, the student is routed to the Welcome Screen and selects "Log In".
  3. Student enters their university email and password.
  4. System validates the credentials and issues a JWT.
  5. App stores the JWT and redirects the student to the Main Feed.
- **Postcondition:** The student is authenticated and lands on the Main Feed.
- **Exception:** Invalid credentials show an error and the student remains on the Log In screen.

#### 4.1.4 Log Out

- **Actors:** Student
- **Brief Description:** Ends the student's authenticated session.
- **Precondition:** The student is logged in.
- **Main Flow:**
  1. Student selects "Log Out" from their profile or settings.
  2. System discards the locally stored JWT.
  3. Student is routed back to the Welcome Screen.
- **Postcondition:** The session is terminated; the next app launch requires Log In or Sign Up.

### 4.2 Search & Filter

#### 4.2.1 Search Students

- **Actors:** Student
- **Brief Description:** Lets a student look up any other verified IBA student by name or batch.
- **Precondition:** The student is logged in.
- **Main Flow:**
  1. Student opens the search bar.
  2. Student types a name.
  3. System performs a direct lookup against the verified-user table and returns matches.
  4. Student selects a result to view that student's profile.
- **Postcondition:** Matching student profiles are displayed.

#### 4.2.2 Filter Feed

- **Actors:** Student
- **Brief Description:** Narrows the main feed by campus, batch, department, or society, with filters that can be combined.
- **Precondition:** The student is logged in and viewing the feed.
- **Main Flow:**
  1. Student opens the filter panel.
  2. Student selects one or more filters (zone, department, society, batch).
  3. System re-queries the feed for posts matching all selected filters.
  4. Feed updates to show matching posts, or an on-brand empty-state message if there are none.
- **Postcondition:** The feed reflects the selected filter combination.

### 4.3 User Profile

#### 4.3.1 View Profile

- **Actors:** Student
- **Brief Description:** Displays a student's profile: photo, post grid, batch/department/society badges, streak, tags, and mood sticker.
- **Precondition:** The student is logged in.
- **Main Flow:**
  1. Student navigates to their own profile or taps another student's name.
  2. System loads the profile info and post grid.
  3. Student taps a post thumbnail to see its full view.
- **Postcondition:** The profile is displayed.

#### 4.3.2 Edit Profile

- **Actors:** Student
- **Brief Description:** Allows a student to update their own profile photo, mood sticker and bio.
- **Precondition:** The student is logged in and viewing their own profile.
- **Main Flow:**
  1. Student selects "Edit Profile".
  2. Student changes their photo (cropped to 1:1, minimum 400×400px), updates their mood sticker, or sets a bio.
  3. System saves the changes with a UI update.
- **Postcondition:** Profile changes are saved and immediately reflected in the UI.
- **Exception:** A student's JWT identity is checked so only the profile owner can edit it.

### 4.4 Content Creation

#### 4.4.1 View Feed

- **Actors:** Student
- **Brief Description:** Displays the main scrollable feed of posts from other verified students.
- **Precondition:** The student is logged in.
- **Main Flow:**
  1. Student opens the Main Feed screen.
  2. System retrieves recent posts, optionally filtered (see Filter Feed).
  3. Student scrolls through posts and can react to or open a post's full view.
- **Postcondition:** The feed is displayed.

#### 4.4.2 Create Post

- **Includes:** Capture Photo (front camera), Capture Photo (back camera)
- **Extended by:** Tag Location
- **Actors:** Student, Push Notification Service
- **Brief Description:** Lets a student capture and publish the daily "IBA Moment" photo (front camera then back camera, sequentially) or a short text post.
- **Precondition:** The student is logged in.
- **Main Flow:**
  1. Push Notification Service sends the randomly-timed "IBA Moment" notification (or the student opens the composer directly for a text post).
  2. Student opens the app within the 2-minute countdown window for the photo prompt.
  3. System executes Capture Photo using the front camera.
  4. System executes Capture Photo using the back camera.
  5. Student may optionally execute Tag Location.
  6. Student optionally adds a caption.
  7. Student submits the post.
  8. The post is published immediately to the feed and added to the student's daily timeline.
- **Postcondition:** The post is published to the feed and the feed unlocks for the student. (A published post can later be flagged through Report Post.)
- **Exception:** If the student misses the 2-minute window, the prompt-based photo post is no longer available that day; a text post remains possible.

#### 4.4.3 Capture Photo

- **Included by:** Create Post
- **Actors:** Student
- **Brief Description:** Captures a single photo using one camera (back), as directed by the calling flow.
- **Precondition:** Create Post has been initiated.
- **Main Flow:**
  1. System opens the capture screen with the back camera active.
  2. Student takes the photo.
  3. The captured image is attached to the in-progress post.
- **Postcondition:** The image is ready to be included with the post.

#### 4.4.4 Tag Location

- **Extends:** Create Post
- **Actors:** Student
- **Brief Description:** Optionally attaches a preset campus-zone tag (library, CED, AMAN Tower, hostel, sports complex, etc.) to a post.
- **Precondition:** The student is composing a post.
- **Main Flow:**
  1. Student opens the location-tag picker.
  2. Student selects one zone from the preset list.
  3. The tag is attached to the post, contributing to the campus "heat map".
- **Postcondition:** The post carries a location tag.

#### 4.4.5 React to Post

- **Actors:** Student
- **Brief Description:** Lets a student respond to another student's post with a lightweight emoji reaction, or open the optional comment thread.
- **Precondition:** The student is logged in and viewing the feed or a post's full view.
- **Main Flow:**
  1. Student taps an emoji reaction on a post.
  2. System records the reaction and updates the post's reaction count.
  3. Student may optionally toggle the comment thread and post a comment.
- **Postcondition:** The reaction (and/or comment) is saved and visible to other students.

#### 4.4.6 Report Post

- **Included by:** Create Post, View Feed
- **Actors:** Student, Development Team (system actor)
- **Brief Description:** A report button is present on all posts. If a post is reported as inappropriate content, it is surfaced to the development team, who manually decide to ignore or remove it.
- **Precondition:** A student is viewing a post in the feed.
- **Main Flow:**
  1. Student taps the report button on a post they believe is inappropriate.
  2. System records the report and adds the post to a review queue visible to the development team.
  3. A developer reviews the reported post and either ignores the report or removes the post from the feed.
- **Postcondition:** Reported posts remain visible until reviewed; the post is either kept (report ignored) or removed based on the developer's manual decision.

## 5. System Class Diagram

*(Generated with mermaidonline.live/ai-class-diagram-generator — see `docs/class-model.md` for the entity breakdown.)*

Classes: `Student`, `Post`, `Reaction`, `Comment`, `Report`, `LocationTag`.

Relationships:

- `Student` **creates** `Post` (1 → 0..\*)
- `Student` **writes** `Comment` (1 → 0..\*)
- `Student` **gives** `Reaction` (1 → 0..\*)
- `Student` **files** `Report` (1 → 0..\*)
- `Post` **has** `Comment` (1 → 0..\*)
- `Post` **receives** `Reaction` (1 → 0..\*)
- `Post` **flagged in** `Report` (1 → 0..\*)
- `Post` **tagged with** `LocationTag` (1 → 0..1)

See [`docs/class-model.md`](class-model.md) for full attribute/method detail per class.
