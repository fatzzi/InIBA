# InIBA — System Class Model

*Generated with mermaidonline.live/ai-class-diagram-generator*

## Student

| Field | Description |
|---|---|
| `studentId: int` | A unique ID number that identifies each student account in the database. |
| `name: string` | The student's full name displayed on their profile and used by others to search for them. |
| `email: string` | The official university email address used for login and identity verification. |
| `passwordHash: string` | An encrypted version of the user's password stored securely so it cannot be read directly. |
| `batch: string` | The graduating class year of the student, used for profiles, searching, and feed filtering. |
| `department: string` | The academic major or program of the student, displayed on their profile. |
| `bio: string` | A short personal description written by the student on their profile. |
| `profilePhoto: string` | The link or path to the student's profile picture. |
| `moodSticker: string` | A lightweight status icon or sticker shown on the student's profile to express their current vibe. |

Methods: `signUp()`, `verifyEmail()`, `login()`, `logout()`, `editProfile()`, `searchStudents()`

## Post

| Field | Description |
|---|---|
| `postId: int` | A unique ID number identifying a specific post. |
| `content: string` | The written text or caption included with the post. |
| `imageFront: string` | The image link captured using the front-facing camera. |
| `imageBack: string` | The image link captured using the rear camera. |
| `timestamp: datetime` | The exact date and time the post was published, used to order the feed chronologically. |
| `isRemoved: bool` | A true/false flag that hides the post from the feed if it is taken down by moderation. |

Methods: `createPost()`, `tagLocation()`

## Reaction

| Field | Description |
|---|---|
| `reactionId: int` | A unique ID number identifying an individual reaction. |

Methods: `addReaction()`

## Comment

| Field | Description |
|---|---|
| `commentId: int` | A unique ID number identifying an individual comment. |
| `text: string` | The written message or reply typed by the student. |
| `timestamp: datetime` | The date and time the comment was posted. |

Methods: `addComment()`

## Report

| Field | Description |
|---|---|
| `reportId: int` | A unique ID number identifying a moderation complaint. |
| `reason: string` | The reason selected by the student explaining why the content is inappropriate. |

Methods: `reportPost()`

## LocationTag

| Field | Description |
|---|---|
| `tagId: int` | A unique ID number identifying a campus location entry. |
| `zoneName: string` | The specific campus area name (like Library, CED, or AMAN Tower) attached to posts. |

## Relationships

| From | Relation | To | Multiplicity |
|---|---|---|---|
| Student | creates | Post | 1 → 0..\* |
| Student | writes | Comment | 1 → 0..\* |
| Student | gives | Reaction | 1 → 0..\* |
| Student | files | Report | 1 → 0..\* |
| Post | has | Comment | 1 → 0..\* |
| Post | receives | Reaction | 1 → 0..\* |
| Post | flagged in | Report | 1 → 0..\* |
| Post | tagged with | LocationTag | 1 → 0..1 |
