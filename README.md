# aws-sagemaker-studio-infra
Sagemaker Studio and AWS Network Firewall

I have a cloudformation template I have been working on and it seems to be working in bayer environment.

I found a cool fix using network firewall

Question for Security experts.
Would I have to monitor DNS traffic to catch this attack in progress?



Pytorch, a third party python library was [compromised on the Python Package Index code repository and runs a malicous binary.](https://thehackernews.com/2023/01/pytorch-machine-learning-framework.html) This impacts a recent nightly build. This build has been fixed and the problem resolved.

The attack uploads all of this information, including file contents (.ssh, .gitconfig), via encrypted DNS queries to the domain *.h4ck[.]cfd, using the DNS server wheezy[.]io

The package is using encrypted DNS and you can't monitor DNS traffic without TLS inspection like the Bayer proxies do.

If DoH is used you can't see that traffic goes to a domain, only to a IP address. So yes, the domain name itself is encrypted. This is one of the advantages of using DoH. You would require a IP to domain mapping to know which domains are being accessed.

Not sure if that is meant with encrypted DNS queries. I think this means DNS tunnel, which is hiding infos in DNS requests to a DNS server the attacker controlls. So something like your client does a query: "the-users-password-is-swordfish.hacker.com" and the DNS server responds with a TXT record "Thank you, now tell me what his name is" or at least along those lines. Since security groups always implicitly allow egress DNS queries you cannot easily block  this. But GuardDuty should detect and prevent it (https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-types-ec2.html#trojan-ec2-dnsdataexfiltration)
