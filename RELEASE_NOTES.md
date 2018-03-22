------------------------
swamp-scms-plugin version releases/1.3.4 (Fri Mar 12 12:40:41 CST 2018)
------------------------
- Updated the list of build-systems.

- Updated the list of valid SWAMP languages.

- Plugin now supports multiple languages; required for web assessments.

- --print-langauges and --print-build-sys options added to display the
  limits of languages and build systems.

- Add support for http_proxy and https_proxy from the config file.

- Updated platforms lists for el7

- Updated commercial / licensed tools for newly supported ones.

- New version of the cli, swamp-java-cli-1.4.0 added to plugin.

------------------------
swamp-scms-plugin version releases/1.3.3 (Wed Nov  15 15:50:23 CST 2016)
------------------------
- Updates to the SCMS plugin to switch to the "new" swamp-cli syntax.  This
  is an internal operation, no user-visible changes.

- New swamp-java-cli 1.3.3 added to plugin.

- The SCMS plugin was automatically correcting for a bug in the swamp-cli's
  uuid output for packages.
  However it didn't check that it needed to make the correction.  Now
  that the cli is fixed, the scms plugin no longer needs to perform that
  bug-fix to cli output.

- Added a couple of "notes" from odd situations users experienced
  trying out releases/1.3; all these problems existed before, but
  with more users, more things have been noted:

- nB: The 'package.conf' file MUST be checked into the SCMS system
  (git or svn) which you are using.   The plugin extracts the current
  workspace from the SCMS to feed to the SWAMP; if package.conf isn't
  added to the SCMS, you will see a 'package.conf missing' error when
  the SWAMP tries to run an assessment.

	git add package.conf
	svn add package.conf

- nB: If you have problems on ubuntu-16.04 with perl errors about missing
  components, install

	  libarchive-extract-perl

  with apt-get:

	  apt-get install libarchive-extract-perl

  Compared to earlier ubuntu releases, Ubuntu 16 shreds perl into many
  components, and no longer installs some "common" perl components
  by default.

- nB: If running on a redhat based system, here are the perl packages
  required beyond perl itself.   A minimal system may not have them
  installed:

	  perl-Archive-Extract
	  perl-Archive-Tar
	  perl-Digest-SHA

  Which can be installed via

  	yum install perl-Archive-Extract perl-Archive-Tar perl-Digest-SHA
	


------------------------
swamp-scms-plugin version releases/1.3 (Wed Nov  1 15:50:23 CST 2016)
------------------------

- Many bug fixes.

- Added complete verification of the entire plugin configuration
  through existing --verify option.

  Always run the uploader with --verify after making configuration
  changes, to verify that everthing is correct.   If it can't pass
  --verify, the configuration will not work.

- Support for newer SWAMPs with os-ver-bits platform names.

- Java used by the plugin can be configured in the plugin config file;
  this allows you development with java which is not compatible with the
  swamp-cli used by the SCMS plugin.

- Backwards compatability for old "descriptive" platform names, with
  --verify noting that those platforms should be updated to new names.

- java-cli updated to 1.3+.

- Added update capabiliity to the installer, to update current an already
  installed plugin to a newer version.

  Any changed "config" files will be installed with a ".instnew" extension
  so it is easy to manually diff and configure existing config files.

- Installer updated to allow login and querying of information from
  a SWAMP to assist in configuring the plugin before it is configured.

- Extensive notes and examples added to the default configuration file.
  Now you can pretty much look at the config and cut/paste what you
  want to use instead of having to query the SWAMP.

------------------------
swamp-scms-plugin version releases/0.6.1 (Tue Dec 20 15:22:45 CST 2016)
------------------------
-Initial Commit

-Uploads a git repository to the SWAMP on a git commit or receive, or an SVN commit

-Also has an installer to install the needed hook files to a repository
