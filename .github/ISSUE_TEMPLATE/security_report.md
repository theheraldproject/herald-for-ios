---
name: Security report
about: Report a specific security concern
title: 'Security Report'
labels: 'verify'
assignees: ''

---

**WARNING*:: IF YOU ARE REPORTING AN ISSUE THAT COULD CAUSE
IMMEDIATE SECURITY CONCERNS THAT PUT DEVICES OR PEOPLE AT RISK THEN
PLEASE INSTEAD FOLLOW THE VMWARE SECURITY VULNERABILITY PROCEDURE:-

https://hackerone.com/vmware?type=team

For other security concerns, please continue.

Note: Please report issues with upstream projects that we rely on (e.g. iOS Core Bluetooth, Android OS, etc.) via these two procedures too.

**NOTE**: This issue tracker is for reporting bugs encountered with the
Herald API and Herald testing applications themselves, not for issues with any downstream
projects that use Herald within their apps. Please report issues with those apps to their
developers and allow those developers to raise any upstream issues
here themselves after they have completed their initial issue investigation. This prevents
rework and delay in getting your issues resolved. Any issues
raised referring to those apps here and not Herald shall be closed. Only raise the issue here if it
has been reproduced with the Herald demonstration app.

Example: If Herald provides 4 options for a piece of security functionality and a downstream app
is using one you believe to be insecure, then please report this as a concern in their issues tracker.

**Describe the security concern**

A clear and concise description of what the security concern is.

**Smartphone and App information (REQUIRED if you have produced an exploit):**

- Device: [e.g. Samsung S20]
- Device exact model (if known): [e.g. SM-G781B] 
- OS exact version: [e.g. iOS8.1, Android 11]
- OS security patch/exact release: [Optional. E.g. 1st Oct 2020. See Settings > Device Information on your phone]
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
- Impact: [LOW = Annoying, but functional. MEDIUM = Impacts function of the app/device, but there's a workaround. HIGH = Stops app/device functioning.]

**Describe the potential solution you'd like**

A clear and concise description of what you want to happen within Herald.

**Describe alternatives you've considered**

A clear and concise description of any alternative solutions or features you've considered.

**DEVELOPERS ONLY: Herald settings in use**

If you are developing an app based on Herald, please indicate the settings you are using
with Herald. In particular:-

- Anything non-default from BLESensorConfiguration: [E.g. payload sharing frequency, and value]
- The Payload provided used: [e.g. Secured Payload]
- The Randomness provider used: [e.g. Secure Random]
- Other (please indicate)

**Additional context**

Add any other context about the problem here.

**Notification**

DO NOT MODIFY THE BELOW - it will alert the maintainers once you submit your report.

@vmware/herald-maintainers

