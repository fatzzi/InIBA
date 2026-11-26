# Wireframes

Full-project wireframes for InIBA (40 screens across authentication, feed/search/filter, profile, IBA Moment/content creation, and reactions/moderation/admin).

- Figma file: https://www.figma.com/design/K0sumZC9C8nrl03gecR08A (3 pages: "1 Auth + IBA Moment", "2 Feed + Moderation", "3 User Profile")
- Submission PDF: `InIBA-wireframes.pdf` (add here after export)

The Jira stories SCRUM-60 to SCRUM-65 track this work.

## Claude design canvas (source)

`claude-design/` holds the source of the first draft of the wireframes: five artboards (`Main`, `Feed`, `Profile`, `Moment`, `Social` `.dc.html`) plus `canvas.json`, the index that positions them. The same 40 screens were then rebuilt in Figma.

These files are in the Claude design-canvas format, which needs that canvas to render (they reference its `support.js`), so they will not open correctly as plain HTML. The Figma file is the one to use for review and for the submission PDF.

| Board | Screens |
|---|---|
| 1 Authentication | Welcome, sign up, sign-up error, OTP, OTP error, log in, profile setup, settings and log out |
| 2 Feed, search, filter | Main feed, full post, search, no results, filter sheet, filtered empty state, locked feed, loading and error |
| 3 User profile | My profile, other profile, edit profile, photo crop, mood picker, timeline, highlights, spotted at |
| 4 IBA Moment | Push notification, countdown, front and back capture, preview and zone, text post, missed window, rejected photo |
| 5 Reactions, moderation, admin | Reaction picker, comments, report dialog, report sent, admin queue, admin decision, FAQ, feedback |

## PNG exports

Two-times-resolution PNGs of every screen, one folder per board (rendered from the design canvas source in `claude-design/`).

**1-authentication**

- [1-1-welcome-no-valid-jwt](png/1-authentication/1-1-welcome-no-valid-jwt.png)
- [1-2-sign-up-form](png/1-authentication/1-2-sign-up-form.png)
- [1-3-sign-up-error-wrong-domain](png/1-authentication/1-3-sign-up-error-wrong-domain.png)
- [1-4-verify-email-otp](png/1-authentication/1-4-verify-email-otp.png)
- [1-5-otp-error-and-rate-limit](png/1-authentication/1-5-otp-error-and-rate-limit.png)
- [1-6-log-in](png/1-authentication/1-6-log-in.png)
- [1-7-profile-setup-first-login](png/1-authentication/1-7-profile-setup-first-login.png)
- [1-8-settings-log-out](png/1-authentication/1-8-settings-log-out.png)

**2-feed-search-filter**

- [2-1-main-feed](png/2-feed-search-filter/2-1-main-feed.png)
- [2-2-full-post-view](png/2-feed-search-filter/2-2-full-post-view.png)
- [2-3-search-typing](png/2-feed-search-filter/2-3-search-typing.png)
- [2-4-search-no-results-empty-state](png/2-feed-search-filter/2-4-search-no-results-empty-state.png)
- [2-5-filter-panel-bottom-sheet](png/2-feed-search-filter/2-5-filter-panel-bottom-sheet.png)
- [2-6-filtered-feed-empty-state](png/2-feed-search-filter/2-6-filtered-feed-empty-state.png)
- [2-7-feed-locked-until-you-post](png/2-feed-search-filter/2-7-feed-locked-until-you-post.png)
- [2-8-loading-and-network-error](png/2-feed-search-filter/2-8-loading-and-network-error.png)

**3-user-profile**

- [3-1-my-profile](png/3-user-profile/3-1-my-profile.png)
- [3-2-another-student-s-profile](png/3-user-profile/3-2-another-student-s-profile.png)
- [3-3-edit-profile](png/3-user-profile/3-3-edit-profile.png)
- [3-4-photo-crop-1-1-min-400-400](png/3-user-profile/3-4-photo-crop-1-1-min-400-400.png)
- [3-5-mood-sticker-picker](png/3-user-profile/3-5-mood-sticker-picker.png)
- [3-6-daily-timeline](png/3-user-profile/3-6-daily-timeline.png)
- [3-7-highlights-create-edit](png/3-user-profile/3-7-highlights-create-edit.png)
- [3-8-spotted-at-ticker](png/3-user-profile/3-8-spotted-at-ticker.png)

**4-iba-moment**

- [4-1-push-notification-lock-screen](png/4-iba-moment/4-1-push-notification-lock-screen.png)
- [4-2-countdown-2-00-window](png/4-iba-moment/4-2-countdown-2-00-window.png)
- [4-3-capture-front-camera](png/4-iba-moment/4-3-capture-front-camera.png)
- [4-4-capture-back-camera](png/4-iba-moment/4-4-capture-back-camera.png)
- [4-5-preview-caption-and-zone](png/4-iba-moment/4-5-preview-caption-and-zone.png)
- [4-6-text-post-composer](png/4-iba-moment/4-6-text-post-composer.png)
- [4-7-missed-the-window](png/4-iba-moment/4-7-missed-the-window.png)
- [4-8-rejected-photo-and-already-posted](png/4-iba-moment/4-8-rejected-photo-and-already-posted.png)

**5-reactions-moderation-admin**

- [5-1-emoji-reaction-picker](png/5-reactions-moderation-admin/5-1-emoji-reaction-picker.png)
- [5-2-comment-thread](png/5-reactions-moderation-admin/5-2-comment-thread.png)
- [5-3-report-post](png/5-reactions-moderation-admin/5-3-report-post.png)
- [5-4-report-sent-duplicate](png/5-reactions-moderation-admin/5-4-report-sent-duplicate.png)
- [5-5-admin-review-queue](png/5-reactions-moderation-admin/5-5-admin-review-queue.png)
- [5-6-admin-decision](png/5-reactions-moderation-admin/5-6-admin-decision.png)
- [5-7-help-faq](png/5-reactions-moderation-admin/5-7-help-faq.png)
- [5-8-send-feedback](png/5-reactions-moderation-admin/5-8-send-feedback.png)
