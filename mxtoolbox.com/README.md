# Description

> This script demonstrates a possible way to bypass HTTP proxies to exfiltrate data and remotely execute code. It accomplishes this by requesting that an HTTP proxy server connects to a permitted web server. That server then submits form data used to "check" a downstream web server. Information is then passed back and forth using the form and an HTTP response header.

# Domains

- https://mxtoolbox.com (Permitted)


# Steps

- Connect to MxToolbox.
- Submit the form to "check" a downstream web server. For the "action" query string parameter, specify "execute_command".
- Get the results. Specifically, get the "Content-Type" HTTP response header. This HTTP header contains the commands to execute.
- Execute the commands.
- Submit the form to "check" a downstream web server. For the "action" query string parameter, specify "send_output".
- Rise and repeat.
