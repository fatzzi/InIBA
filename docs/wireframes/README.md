# Wireframes

Full-project wireframes for InIBA (39 screens across authentication, feed/search/filter, profile, IBA Moment/content creation, and reactions/moderation/admin).

- Figma file: https://www.figma.com/design/K0sumZC9C8nrl03gecR08A (3 pages: "1 Auth + IBA Moment", "2 Feed + Moderation", "3 User Profile")
- Submission PDF: `InIBA-wireframes.pdf` (add here after export)

The Jira stories SCRUM-60 to SCRUM-65 track this work.

## Claude design canvas (source)

`claude-design/` holds the source of the first draft of the wireframes: five artboards (`Main`, `Feed`, `Profile`, `Moment`, `Social` `.dc.html`) plus `canvas.json`, the index that positions them. The same 39 screens were then rebuilt in Figma.

These files are in the Claude design-canvas format, which needs that canvas to render (they reference its `support.js`), so they will not open correctly as plain HTML. The Figma file is the one to use for review and for the submission PDF.

| Board | Screens |
|---|---|
| 1 Authentication | Welcome, sign up, sign-up error, OTP, OTP error, log in, profile setup, settings and log out |
| 2 Feed, search, filter | Main feed, full post, search, no results, filter sheet, filtered empty state, locked feed, loading and error |
| 3 User profile | My profile, other profile, edit profile, photo crop, mood picker, timeline, highlights, spotted at |
| 4 IBA Moment | Push notification, countdown, front and back capture, preview and zone, text post, missed window, rejected photo |
| 5 Reactions, moderation, admin | Reaction picker, comments, report dialog, report sent, admin queue, admin decision, FAQ, feedback |
