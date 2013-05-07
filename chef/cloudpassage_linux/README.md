cloudpassage_linux Cookbook
=============================
This cookbook installs Halo on Debian, Ubuntu, CentOS, Fedora, RHEL and Amazon Linux servers.

Requirements
------------
The default recipe relies on sudo and curl being installed. It does not list them as cookbook dependencies.

Attributes
----------
There are default attributes that need to be updated with your specific daemon-key and serverGroup tag naming scheme.

default[:cloudpassage_linux][:daemon_key] = "abc123abc123abc123abc123abc123ab"<br>
default[:cloudpassage_linux][:tag] = "chefRocks"<br>

Usage
-----
```
knife bootstrap <your server instance FQDN> -x <root|ec2-user, other privileged user_name> -i “~/.ssh/<ssh_key>” -r "cloudpassage_linux" --sudo
```

License and Authors
-------------------
Authors: Eric Hoffmann <ehoffmann@cloudpassage.com> 

Copyright (c) 2013, CloudPassage, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the CloudPassage, Inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL CLOUDPASSAGE, INC. BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED ANDON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
