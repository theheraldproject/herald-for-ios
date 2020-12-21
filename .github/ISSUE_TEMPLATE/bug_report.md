---
name: Bug report
about: Create a report about a specific issue
title: 'Bug Report'
labels: 'verify'
assignees: ''

---

**NOTE**: This issue tracker is for reporting bugs encountered with the
Herald API and Herald testing applications themselves, not for issues with any downstream
projects that use Herald within their apps. Please report issues with those apps to their
developers and allow those developers to raise any upstream issues
here themselves after they have completed their initial issue investigation. This prevents
rework and delay in getting your issues resolved. Any issues
raised referring to those apps here and not Herald shall be closed. Only raise the issue here if it
has been reproduced with the Herald demonstration app.

**Describe the bug**

A clear and concise description of what the bug is.

**Smartphone and App information (REQUIRED):**

- Device: [e.g. Samsung S20]
- Device exact model (if known): [e.g. SM-G781B] 
- OS exact version: [e.g. iOS8.1]
- Herald demonstration app version: [e.g. Release ID (v1.2.0-beta3), latest develop branch, or commit ID]
- Have you reproduced this issue on the latest 'develop' Herald branch?: [Yes, No]

Without the above information the Herald team will be unable to reproduce 
the issue, and thus also unable to fix and confirm the fix for the issue.

If the above information is not provided then the issue will be marked
as 'cannot reproduce'.

**Severity (Project team may edit this section after reporting)**

Please provide the following metrics (optional, can be filled in by project team if left blank):-

- Likely How Widespread: [LOW = Less than 5% of installs of this (iOS, Android) variant, MEDIUM = 5%-50%, HIGH = More than 50%]
- Reproducability: [NONE = Lab only/theoretical, or an unlikely user activity. LOW = Intermittent, unpredictable. MEDIUM = Occurs often, but unpredictable. HIGH = Easy to reproduce]
- Impact: [NONE/LOW = Annoying, but functional. MEDIUM = Impacts function of the app/device, but there's a workaround. HIGH = Stops app/device functioning.]

**To Reproduce**

Steps to reproduce the behavior:

1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**

A clear and concise description of what you expected to happen.

**Screenshots**

If applicable, add screenshots to help explain your problem.

**DEVELOPERS ONLY: Herald settings in use**

If you are developing an app based on Herald, please indicate the settings you are using
with Herald. In particular:-

- Anything non-default from BLESensorConfiguration: [E.g. payload sharing frequency, and value]
- The Payload provided used: [e.g. Secured Payload]
- The Randomness provider used: [e.g. Secure Random]
- Other (please indicate)

**Additional context**

Add any other context about the problem here.
