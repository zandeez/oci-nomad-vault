Rotating CA
===========

Sometime before expiry of current CA, rotate the key, give the issuer a new name

    vault write pki/root/rotate/internal issuer_name="<name>" not_after="<timestamp>" (or ttl="") 

Update the auth/pki/matrix role to have both CAs

Wait some time for the new certificate to filter down

Change the default issuer to the new CA

    vault write pki/root/replace default="<name>"

Wait the the old certificate expires, then remove it

    vault write pki/issuer/<old_name> issuse_name="<old_name>" usage=read-only,crl-signing

This can probably go into a cron job or nomad periodic task
