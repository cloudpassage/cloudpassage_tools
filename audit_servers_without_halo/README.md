Audit Servers in Multi-Cloud environments for the installation of Halo
==================
The audit_servers_without_halo_installed.rb script checks AWS regions and Rackspace
for servers that do not have Halo installed. It might be the case that a server
was deployed adhoc, or outside of a defined DEVOPS process. This script discovers
those instances and creates a report containing identifying attributes to help
understand where the instance was deployed and possibly why. The number of cloud
providers and regions can be customized and we encourage those updates. AWS and
Rackspace are provided only as an example.

Update the "providers" Hash with your specific Cloud Provider, credential_path
and regions where you have servers deployed. Lines 118-135 are were the updates
should be applied.

```
118 # Define providers, credential_paths and regions (if applicable) your servers
119 # reside. add/update this based on your environment
120 # example format for the file defined as credential_path:
121 # :default:
122 #     :aws_access_key_id:     ABC123ABC123ABC123AB
123 #     :aws_secret_access_key: ABC123ABC123ABC123ABC123ABC123ABC123ABC1
124 # or
125 # :default:
126 #     :rackspace_username:  user_name
127 #     :rackspace_api_key:   ABC123ABC123ABC123ABC123ABC123ABC123ABC1
128 providers = { "AWS" => ["/path/to/fog_aws", ['us-west-1', 'us-east-1']],
129               "Rackspace" => ["/path/to/fog_rackspace", ['N/A']]}
130 
131 # Pass in portal, key_id, key_secret to setup API session
132 # key_id/key_secret can be created from portal.cloudpassage.com
133 # Settings > Site Administration > API Keys
134 # At least a read-only key is required
135 @api = APICalls.new("api.cloudpassage.com", 'abc123abc', 'abc123abc123abc123abc123abc123ab')
```

The expected output should look like the following:
```
ruby audit_servers_without_halo_installed.rb
Halo is not installed on: AWS, ["22.23.123.119", ["ec2-22-23-123-119.compute-1.amazonaws.com", "i-4ab7gd19", "ehoffmann-staging-srv1"]]
Halo is not installed on: Rackspace, ["54.23.211.72", ["Dev-Testing", "31232944"]]
Halo is not installed on: Rackspace, ["50.46.116.14", ["Prod-DB-1", "11437928"]]
```
