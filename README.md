# CI/CD with Apache2

## Table of Contents

- [CI/CD with Apache2](#cicd-with-apache2)
	- [Table of Contents](#table-of-contents)
	- [Server Setup (with SSL)](#server-setup-with-ssl)
	- [Server Config for SPAs (React Router)](#server-config-for-spas-react-router)
		- [Instructions](#instructions)
		- [Explanation](#explanation)
	- [Apache2 Webhooks for CI/CD with GitHub](#apache2-webhooks-for-cicd-with-github)
	- [Creating the GitHub Deployment Workflow](#creating-the-github-deployment-workflow)


## Server Setup (with SSL)

Always start a new server off with `apt update` and `apt upgrade`

Give the server static IPs so they don't change between reboots:
`/etc/netplan/00-installer-config.yaml`
```
network:
  ethernets:
    ens160:
      addresses:
        - 10.0.0.<IP>/24
    ens192:
      addresses:
        - 192.168.1.<IP>/24
    ens224:
      addresses:
        - 172.16.4.<IP>/24
      nameservers:
        addresses: [10.0.0.213,172.16.4.213,192.168.1.213]
      routes:
        - to: default
          via: 172.16.4.2
  version: 2
```
> **Note:** The IPs specified in this example may not match your network's configuration. Be sure to double check before applying changes.

Then run `netplan apply` to put it into effect.

Install apache2 and allow its ports (443 for https; 80 for http):
```
apt install apache2
ufw allow Apache
ufw allow Apache Secure
ufw allow <RELEVANT PORT>
```

Upload SSL cert files over FTP, then move them to their secure locations:
```
mv <KEY>.key /etc/ssl/private/<KEY>.key
mv <CERT>.crt /etc/ssl/certs/<CERT>.crt
mv <BUNDLE>.crt /etc/ssl/certs/<BUNDLE>.crt
```
> **Note:** The above example assumes your present working directory houses the FTP'ed files. Of course, you could always use absolute paths instead.

Configure the Apache web server to work with SSL:
`nano /etc/apache2/sites-available/<SITE NAME>.conf`
```
<IfModule mod_ssl.c>
	<VirtualHost 0.0.0.0:443>
		ServerName <domain name>
		ServerAlias <domain name>

		ServerAdmin <desired email address>
		DocumentRoot /var/www/<SITE NAME>/
		SSLEngine on
		SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
		SSLCipherSuite

		SSLCompression      off
		SSLSessionTickets   off
		SSLHonorCipherOrder on

		SSLCertificateFile    /etc/ssl/certs/<CERT>.crt
		SSLCertificateKeyFile /etc/ssl/private/<KEY>.key
		SSLCACertificateFile  /etc/ssl/certs/<BUNDLE>.crt

		<FilesMatch "\.(cgi|shtml|phtml|php)$">
			SSLOptions +StdEnvVars
		</FilesMatch>

		<Directory /usr/lib/cgi-bin>
			SSLOptions +StdEnvVars
		</Directory>

		BrowserMatch "MSIE [2-6]" \
		nokeepalive ssl-unclean-shutdown \
		downgrade-1.0 force-response-1.0
		BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

		ErrorLog ${APACHE_LOG_DIR}/error.log
		CustomLog ${APACHE_LOG_DIR}/access.log combined
	</VirtualHost>
</IfModule>
```

Then disable the default config and enable the new config w/ SSL support:
```
a2dissite 000-default.conf
a2enmod ssl
a2enmod <SITE NAME>.conf
systemctl reload apache2
```

Set up the directory for the new site with `mkdir /var/www/<SITE NAME>`, then stick your site files in there and you're good to go!

## Server Config for SPAs (React Router)

### Instructions

Update site config (`/etc/apache2/sites-available/<SITE NAME>.conf`) with rewrite rules for the site directory:
```
<IfModule mod_ssl.c>
	<VirtualHost 0.0.0.0:443>
		ServerName <domain name>
		ServerAlias <domain name>

		ServerAdmin <desired email address>
		DocumentRoot /var/www/<SITE NAME>/
		SSLEngine on
		SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
		SSLCipherSuite

		SSLCompression      off
		SSLSessionTickets   off
		SSLHonorCipherOrder on

		SSLCertificateFile    /etc/ssl/certs/<CERT>.crt
		SSLCertificateKeyFile /etc/ssl/private/<KEY>.key
		SSLCACertificateFile  /etc/ssl/certs/<BUNDLE>.crt

		<FilesMatch "\.(cgi|shtml|phtml|php)$">
			SSLOptions +StdEnvVars
		</FilesMatch>

		<Directory /usr/lib/cgi-bin>
			SSLOptions +StdEnvVars
			Options -Indexes +FollowSymLinks
		</Directory>

######################### NEW CODE ###########################
		<Directory /var/www/<SITE NAME>>
			RewriteEngine on
			RewriteCond %{REQUEST_FILENAME} -f [OR]
			RewriteCond %{REQUEST_FILENAME} -d
			RewriteRule ^ - [L]
			RewriteRule ^ index.html [L]
		</Directory>
##############################################################

		BrowserMatch "MSIE [2-6]" \
		nokeepalive ssl-unclean-shutdown \
		downgrade-1.0 force-response-1.0
		BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

		ErrorLog ${APACHE_LOG_DIR}/error.log
		CustomLog ${APACHE_LOG_DIR}/access.log combined
	</VirtualHost>
</IfModule>
```

Enable the rewrite module with `a2enmod rewrite`, then enact the changes with `systemctl reload apache2`

### Explanation

Single page applications (SPAs) bundle all "pages" into a single index.html for a smoother app-like experience for the end users. However, web servers such as Apache were not built with SPAs in mind -- by default, they assume that any requested URL should have a matching file path that houses the content to serve. Thus, when deploying a SPA with Apache, the server's configuration must be updated to support the modern webpage.

That's where the Rewrite Engine comes in! The engine allows for Apache to serve URLs that do not strictly correspond to the actual file paths. The Rewrite Conditions in this config instruct the engine to serve any files at the paths that do match the given URL. In the event that there are no equivalent files, rather than serving a 404 error, the Rewrite Rules direct the engine to simply serve index.html. With a SPA that utilizes React Router, the internal router (housed within index.html) will take the given URL and display the corresponding page from within the single document.

This implementation is client-side rendering instead of server-side rendering.

## Apache2 Webhooks for CI/CD with GitHub

> **Note:** These instructions are specifically for GitHub and will not work with a GitLab setup without significant modifications. At this time, I do not have specific instructions for GitLab pipelines. If that changes, it will be reflected here.

To get started with webhooks on Ubuntu, install [webhook](https://github.com/adnanh/webhook) with `sudo apt-get install webhook`. The default port used for hooks is 9000, so the port will need to be made available on the firewall with the command `sudo ufw allow 9000`.

All webhooks are custom and thus do not come pre-defined, so begin by creating the `hooks.json` file to instruct [webhook](https://github.com/adnanh/webhook) of the available hooks. By default, this file is expected to be located at `/var/webhook/hooks.json`, but this can be changed in the config.

Copy the contents of this repository's `hooks.json` found in the `webhooks` folder [here](/webhooks/hooks.json) into your new file. Before saving, ensure that the variables \<encased in arrows\> are replaced with the correct values for your configuration. The `<LOCAL IP>` match case can be removed if you are not setting up redundant servers; otherwise, it should be set to the local IP of the twin server.

> **Note:** The `<MY SECRET>` variable can be anything you'd like. It will be used to ensure that the webhook is only triggered by a trusted source.

Before our hook is ready to listen to the public internet, we need to add the script it will be calling. Create a new file, `/var/scripts/pull-site-changes.sh` and copy the contents of this repository's [file of the same name](webhooks/pull-site-changes.sh). Again, remember to replace the variables \<encased in arrows\> before saving.

You will need a GitHub classic token with read permissions to use in the script's curl request. It is **very** important that you test your setup thoroughly, as misuse of the GitHub API with your access token attached **will** get your account suspended. While safeguards have been implemented to prevent infinite loops between twin servers, always double check your setup and make any necessary changes to secure your account.

A couple more action items before the webhook service can launch:
- The script must also be converted into an executable with `sudo chmod -x /var/scripts/<SCRIPT NAME>.sh`.
- `unzip` must be installed: `sudo apt-get install unzip`

Now the webhook service can begin listening! Replace the variables \<enclosed in arrows\> with those from your setup and then run the following command:
```
webhook -hooks /var/webhook/hooks.json -secure -cert /etc/ssl/certs/<SSL CERT>.crt -key /etc/ssl/private/<SSL KEY>.key -ip <THIS SERVER'S IP> -verbose
```
> **Note:** If your `hooks.json` file is located in a different directory, specify that here. The `-verbose` flag is optional, but recommended for debugging at least.

If you are setting up a pair of redundant web servers, repeat this process on both. Ensure the IPs in `hooks.json`, `pull-site-changes.sh`, and the webhook service startup command are altered correctly for each server.

If you are **not** utilizing a twin-server setup, note that the `$AMOUNT` and `$NEEDS_PARITY` variables and their respective code blocks within the script will not be needed. Remove them if desired.

## Creating the GitHub Deployment Workflow

The explanation for this section is coming soon. However, it is a straightfoward process: check out the [workflow file](.github/workflows/vite-build.yaml) in this repository to get started.
