# Security

Keyfari holds two sensitive permissions: **Accessibility**, which lets it read the interface of other applications, intercept the keyboard while a mode is active and send clicks, and optionally **Screen Recording**, which lets it capture a window for on-device text detection. A flaw in how these are used is a security issue.

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's private vulnerability reporting instead: on the repository page, open the **Security** tab and choose **Report a vulnerability**.

Include what you found, how to reproduce it, and the macOS and Keyfari versions.

## What to expect

Keyfari is maintained by volunteers, so there is no guaranteed response time. Reports are read and answered as soon as possible, and fixes are credited to the reporter unless they prefer otherwise.

## Scope

In scope: anything that lets another process or a crafted application make Keyfari leak screen or interface content, swallow or inject input outside an active mode, or act on the user's behalf without their key presses.

Out of scope: what an attacker can do after already gaining the Accessibility permission themselves, and issues in macOS.
