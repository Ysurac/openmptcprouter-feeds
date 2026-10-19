Contribution

When submitting a pull request for the first time, you will need to agree to the contributor license agreement (for individuals or entities). To do this, in the pull request please create a file with a name like /contributors/{github_username}.md, and in the content of that file indicate your agreement. An example of what that file should contain can be seen in example agreement file.

(This method of CLA "signing" is borrowed from Medium's open source project.)

## AI-assisted contributions

You may use AI tools, but you are the author of what you submit, and review
time is limited. Pull requests that do not follow these rules will be closed
without review.

- **Disclose it.** Say in the pull request which tool you used and for what
  (whole patch, part of it, commit message, tests...).
- **Understand it.** You must be able to explain every line and answer review
  questions yourself. Do not paste AI-generated replies to review comments.
- **Test it on a router.** OpenMPTCProuter runs on OpenWrt (BusyBox ash, musl,
  procd, fw4/nftables, uci, ubus). Code that only works on a workstation does
  not count as tested. Say what you tested: device or target, OMR version, VPS
  version if relevant, and the steps you followed.
- **Fix a real problem.** Link the issue or discussion that describes the bug
  you hit or the feature you need. Do not open pull requests for speculative
  "improvements", mass refactoring, style-only changes, or findings from
  automated scanners without a reproduction.
- **Keep it small.** One logical change per pull request, and no more than 3
  open pull requests at a time.
- **Write issues yourself.** Bug reports and discussions must describe what you
  saw on your setup, with logs. Do not post AI-generated analysis that you have
  not checked.

Security issues must not be reported in a public pull request or issue. Use
GitHub's private vulnerability reporting instead.

Repeated low-effort submissions may lead to being blocked from the repository.
