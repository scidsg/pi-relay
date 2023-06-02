# FAQ

## How do I check my relay's logs?
There are two ways to view logs. 

1. You can check Nyx to see real-time activity and logging. To open Nyx enter:

```
sudo su && nyx
```

You should see this:

![nyx](https://github.com/scidsg/pi-relay/assets/28545431/f507ce49-84a0-4387-83dc-55637afda042)

2. You can view Tor's log file:

```
nano /var/log/tor/notices.log
```

## Nyx shows that relaying is disabled. Is it working?
First, it's important to check Tor's logs to see what's happening. Something to look for is a message about hibernation. Depending on what you set for your relay's max bandwidth, and when it is during the month, Tor will go into hibernation so it can optimize your relay's utility.
For example, if you set a max bandwidth to 1 GB and it's the first of the month, your relay may hibernate until the end of the month.
If you set your max bandwidth to 1.5 TB, it'll likely never go into hibernation.

## Relaying isn't disabled, but Nyx shows no activity. Did I configure it correctly? 
First, make sure your relay isn't hibernating as in the example above.
When you launch Nyx you should see a message that looks like this:

```
Now checking whether IPv4 ORPort xxx.xxx.xxx.xxx:443 is reachable... (this may take up to 20 minutes
 │   -- look for log messages indicating success)
```

If your relay is functioning properly you'll see this message:

```
Self-testing indicates your ORPort xxx.xxx.xxx.xxx:443 is reachable from the outside. Excellent.
 │   Publishing server descriptor.
```

If you don't see the second message, **make sure your router's port forwarding settings are properly configured.**
