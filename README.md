# CI/CD with Apache2

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
        - 172.16.4.187/24
      nameservers:
        addresses: [10.0.0.213,172.16.4.213,192.168.1.213]
      routes:
        - to: default
          via: 172.16.4.2
  version: 2
```
Then run `netplan apply` to put it into effect.

Install apache2 and allow its ports (443 for https ; 80 for http)
```
apt install apache2
ufw allow Apache
ufw alow Apache Secure
ufw allow <RELEVANT PORT>
```

Upload SSL certs over FTP, then move them to their secure locations:
```
mv <KEY>.key /etc/ssl/private/<KEY>.key
mv <CERT>.crt /etc/ssl/certs/<CERT>.crt
mv <BUNDLE>.crt /etc/ssl/certs/<BUNDLE>.crt
```

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
		SSLCipherSuite (note: is this unique or??? google this)

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

Set up the directory for the new site with `mkdir /var/www/<SITE NAME>`, then stick your site files in there are you're good to go!

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
		SSLCipherSuite (note: is this unique or??? google this)

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

##################### NEW CODE #######################
		<Directory /var/www/<SITE NAME>>
			RewriteEngine on
			RewriteCond %{REQUEST_FILENAME} -f [OR]
			RewriteCond %{REQUEST_FILENAME} -d
			RewriteRule ^ - [L]
			RewriteRule ^ index.html [L]
		</Directory>
######################################################

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

This section coming soon, but see the webhooks folder in the repo for an idea.
