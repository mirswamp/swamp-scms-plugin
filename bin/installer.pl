#!/usr/bin/perl
#  SWAMP SCMS Hooks
#
#  Copyright 2016-2017	Jared Sweetland, Vamshi Basupalli,
#  			James A. Kupsch, Josef "Bolo" Burger
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express implied.
#  See the License for the specific language governing permissions and

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromString);
use File::Copy;
use Archive::Extract;
use File::Path;
use File::Basename;

sub ProcessOptions {

	my %options = (
			help		=> 0,
			version		=> 0,
			svn		=> 0,
			git		=> 0,
			print_tools	=> 0,
			print_platforms	=> 0,
			print_projects	=> 0,
			print_packages	=> 0,
			login		=> 0,
			logout		=> 0,
			swamp_url	=> "http://mir-swamp.org/",
			post_commit	=> 1,
			post_receive	=> 0,
			force		=> 0,
			global		=> 0,
			update		=> 0,
			);

	my @options = (
			"help|h",
			"version|v",
			"svn|s",
			"git|g",
			"print_tools|print-tools|t",
			"print_platforms|print-platforms|p",
			"print_projects|print-projects|j",
			"print_packages|print-packages|k",
			"login|l",
			"logout",
			"swamp_url|swamp-url|u=s",
			"force|f",
			"global",
			"update",
			"post_commit|post-commit|commit|c",
			"post_receive|post-receive|push|r",
			);

	$options{jar_name} = "swamp-cli-jar-with-dependencies.jar";

	my $ok = GetOptions(\%options, @options);
	
	($options{prog_name},$options{prog_dir},$options{prog_ext}) = fileparse($0);
	$options{prog_dir} = substr ($options{prog_dir}, 0, length ($options{prog_dir}) - 4);

	if ($options{prog_dir} eq ""){
                $options{prog_dir} = ".";
        }

        $options{repo} = $ARGV[0];

        if (!$ok || $options{help})  {
                PrintUsage();
                exit !$ok;
        }

        if ($options{version})  {
                PrintVersion(\%options);
                exit 0;
        }

	my $print_things = ( $options{print_tools} || $options{print_platforms}
		|| $options{print_projects} || $options{print_packages} );

	my $jar = "$options{prog_dir}/bin/$options{jar_name}";


	if ($options{login} ) {
		system("java", "-jar", $jar, "login", "-S", "$options{swamp_url}", "-C");
	}

	if ($options{print_tools}){
		#system("$options{prog_dir}/bin/uploadPackage.pl --print_tools --main-script $options{prog_dir}/bin/run-main.sh --verbose");
		system("java", "-jar", $jar, "tools", "-list");
        }
        if ($options{print_platforms}){
		#system("$options{prog_dir}/bin/uploadPackage.pl --print_platforms --main-script $options{prog_dir}/bin/run-main.sh --verbose");
		system("java", "-jar", $jar, "platform", "-list");
        }
        if ($options{print_projects}){
		#system("$options{prog_dir}/bin/uploadPackage.pl --print_projects --main-script $options{prog_dir}/bin/run-main.sh --verbose");
		system("java", "-jar", $jar, "project", "-list");
        }
        if ($options{print_packages}){
		#system("$options{prog_dir}/bin/uploadPackage.pl --print_projects --main-script $options{prog_dir}/bin/run-main.sh --verbose");
		system("java", "-jar", $jar, "package", "-list");
        }

	if ( $options{logout} ) {
		system("java", "-jar", $jar, "logout");
	}

	if ($print_things) {
		exit;
	}


	return \%options;

}

sub PrintUsage {
	my $progname = $0;
        $progname =~ s/.*[\\\/]//;

        print STDERR <<EOF;
Usage: $progname --options <arguments>... <repository directory>

Installs the SWAMP api, hook, and README archives and places them in the directory specified by -d.
    options:
	--help		  -h print this message
	--version	  -v print version of $progname
	--svn		  -s specify an svn repository to install the hook
	--git		  -g specify a git repository to install the hook
	--login		  -l Login to the SWAMP; needed to use print-xxx.
			     Login && print-xxx can both be used.  Once a login
			     is performed, print-xxx will be available until
			     the credentials are destroyed by the updater,
			     or via --logout.
	--logout	     Logout from the SWAMP.
	--print-tools	  -t Display the available tools
	--print-platforms -p Display the available platforms
	--print-projects  -j Display the available projects
	--print-packages  -k Display the available packages
	--swamp-url	  -u specify a url for listing packages and updating
			     config files
	--post-commit	  -c installs the commit version script; -- commits
			     will trigger uploading (implied with svn)
	--post-receive	  -r installs the push version script; -- receiving
			     a push will trigger uploading (git exclusive)
	--force		  -f Overwrite any existing files inside your
			     hooks directory on installation.  nB: This will
			     destroy existing configurations, credentials,
			     and scms hook configurations!
	--global	     Install global config/cred file templates in ~/
	--update	     Update SWAMP SCMS plugins software w/out changing
			     the configuration.  This allows installation of
			     software updates to the uploader & swamp-cli.
EOF
}

sub PrintVersion {
	#my $progname =  $0;
        #$progname =~ s/.*[\\\/]//;
	#my $version = "0.9.0";
	#print STDERR "$progname\nVersion $version";
	my $options = $_[0];
	system("$options->{prog_dir}/bin/uploadPackage.pl","-v");
}

sub main {
	my $options = ProcessOptions();

	unless (exists $options->{repo} && length($options->{repo}) ) {
		ExitProgram($options, "Repository not specified.");
	}

	my $repo = $options->{repo};

	unless (-e $repo) {
		ExitProgram($options, "Repository $repo does not exist.");
	}
	unless (-d $repo) {
		ExitProgram($options, "Repository $repo not a directory.");
	}

	## connect to the .git part of the repo if it is a workspace
	my $git_dir = "$repo/.git";
	if (-d $git_dir && $options->{git}) {
		$options->{repo} = $git_dir;
	}

	my $prog_name		= $options->{prog_name};

	if ($options->{git}) {
		unless ($options->{post_receive} || $options->{post_commit}){
			ExitProgram($options, "You must specify either --post-receive or --post-commit with a git repository.\n$!");
		}
	}
	elsif ($options->{svn}) {
		if ($options->{post_receive}) {
			ExitProgram($options, "--post-receive only works for a git repository.");
		}
		if (!$options->{post_commit}) {
			print STDERR "$prog_name: svn enabling --post-commit\n";
			$options->{post_commit} = 1;
		}
	}
	else {
		ExitProgram($options,
		"Repository type not specified; specify --git or --svn");
	}

	## Find which files are already installed; check depends on force/update

	my $hooks_dir	= "$options->{repo}/hooks";
	my $post_rcv	= "$hooks_dir/post-receive";
	my $post_com	= "$hooks_dir/post-commit";

	my $swamp_dir	= "$hooks_dir/SWAMP_Uploader";
	my $uploader	= "$swamp_dir/uploadPackage.pl";
	my $java_cli	= "$swamp_dir/$options->{jar_name}";
	my $config_file	= "$swamp_dir/uploadConfig.conf";
	my $cred_file	= "$swamp_dir/uploadCredentials.conf";

	## global config files which mean sophisticated user
	my $homedir		= glob('~');
	my $global_config_file	= "$homedir/.SWAMPUploadConfig.conf";
	my $global_cred_file	= "$homedir/.SWAMPUploadCredentials.conf";

	## source files for everything
	my $bin_dir		= "$options->{prog_dir}/bin";
	my $post_rcv_git_src	= "$bin_dir/post-receive";
	my $post_com_git_src	= "$bin_dir/post-commit.git";
	my $post_com_svn_src	= "$bin_dir/post-commit.svn";
	my $uploader_src	= "$bin_dir/uploadPackage.pl";
	my $java_cli_src	= "$bin_dir/$options->{jar_name}";

	my $tmpl_dir		= "$options->{prog_dir}/config";
	my $config_tmpl		= "$tmpl_dir/uploadConfig.template";
	my $cred_tmpl		= "$tmpl_dir/uploadCredentials.template";

	my @existingFiles;
	{
		## updates don't destroy
		if (!$options->{update}) {
			if (-e $uploader ) {
				push @existingFiles, $uploader;
			}
			if ( -e $java_cli ) {
				push @existingFiles, $java_cli;
			}
		}

		## things untouched by an update
		if (!$options->{update}) {
			if ($options->{post_receive} && $options->{git} && -e $post_rcv) {
				push @existingFiles, $post_rcv;
			}
			if ($options->{post_commit} && -e $post_com) {
				push @existingFiles, $post_com;
			}
		}

		## updates don't destroy
		if (!$options->{update}) {
			if ( -e $config_file ) {
				push @existingFiles, $config_file;
			}
			if ( -e $cred_file ) {
				push @existingFiles, $cred_file;
			}
		}

		## updates don't destroy
		if (!$options->{update} && $options->{global}) {
			if ( -e $global_config_file ) {
				push @existingFiles, $global_config_file;
			}
			if ( -e $global_cred_file ) {
				push @existingFiles, $global_cred_file;
			}
		}
	}
	if (!$options->{force}) {
		if (@existingFiles) {
			ExitProgram($options, "Files already installed:\n\t". join("\n\t", @existingFiles) ."\nUse --update and/or --force as needed if\nyou would like to update or replace them.");
		}
	}

	## hooks dir may not exist (doesn't in svn)
	if ( ! -e $hooks_dir ) {
		mkdir($hooks_dir)
			or ExitProgram($options,
			"fail create directory \"$hooks_dir\"\n$!");
	}
	elsif ( ! -d $hooks_dir ) {
		ExitProgram($options, "${hooks_dir}: not a directory.");
	}

	if ( ! -e $swamp_dir ) {
		mkdir($swamp_dir)
			or ExitProgram($options,
			"fail create directory \"$swamp_dir\"\n$!");
	}
	elsif ( ! -d $swamp_dir ) {
		ExitProgram($options, "${swamp_dir}: not a directory.");
	}

	## local config and credtial templates
	## The config files can be precious, try to save them
	## Try our best to save config files, unless the user
	## asks to trash them with --force.
	### XXX this open-coded stuff is for the birds
	{
		my ($config_file_dest, $cred_file_dest);

		$config_file_dest = copy_instnew($options,
						 $config_tmpl,
						 $config_file);
#		chmod( 0644, $config_file_dest );

		$cred_file_dest = copy_instnew($options,
					       $cred_tmpl,
					       $cred_file);
		chmod( 0600, $cred_file_dest );
	}
	
	## global config if specified
	if ($options->{global}) {
		my ($global_config_file_dest, $global_cred_file_dest);

		$global_config_file_dest = copy_instnew($options,
							$config_tmpl,
							$global_config_file);
#		chmod( 0644, $global_config_file_dest );

		$global_cred_file_dest = copy_instnew($options,
						      $cred_tmpl,
						      $global_cred_file);
		chmod( 0600, $global_cred_file_dest );

	}

	# nB: if symlink versions, don't destroy the version the symlink
	# points at.  This can over-write user changed files.

	if ( -l $uploader ) {
		unlink $uploader
			or ExitProgram($options, "failed to remove symlink $uploader: $!");
	}

	copy($uploader_src, $uploader)
		or ExitProgram($options, "failed copy uploadPackage.pl: $!");
	chmod( 0755,  $uploader );

	## if symlinked to something else, don't destroy the orginal
	if ( -l $java_cli ) {
		unlink $java_cli
			or ExitProgram($options, "failed to remove symlink $java_cli: $!");
	}
	copy($java_cli_src, $java_cli)
		or ExitProgram($options,
				"failed copy $options->{jar_name}: $!");

	## parameterize hook source file and destination file
	my $hook_src;
	my $hook_file;
	if ($options->{git}){
		if ($options->{post_commit}){
			$hook_src = $post_com_git_src;
			$hook_file = $post_com;
		}
		if ($options->{post_receive}) {
			$hook_src = $post_rcv_git_src;
			$hook_file = $post_rcv;
		}
	}
	elsif ($options->{svn}) {
		$hook_src = $post_com_svn_src;
		$hook_file = $post_com;
	}

	my $hook_file_dest = copy_instnew($options, $hook_src, $hook_file);
	chmod( 0755, $hook_file_dest );

	if ($hook_file_dest ne $hook_file) {
		print "$prog_name: Existing git/svn hook $hook_file NOT UPDATED\n";
		print "\tPlease review any changes to $hook_file_dest\n";
		print "\tand integrate them into your hook as appropriate.\n";
	}

}

sub ExitProgram {
	my ($options, $output) = @_;
	print STDERR "$output\n";
	exit 1;
}

## copy a file into place; if an existing version, make a .instnew
## and leave the original alone.   Return the name of the copied file;
## which may be different than the original name.
sub copy_instnew {
	my ($options, $src, $dst) = @_;

	my $tag = basename( $dst );		## short message name
	my $final_dst = $dst;
	my $prog_name = $options->{prog_name};

	if ( -e $dst ) {
		## an update NEVER overwrites configuration information.
		## --force --update doesn't over-write config
		## --force overwrites everything
		if ( !$options->{force} || $options->{update} ) {
			$final_dst = "${dst}.instnew";
			print "$prog_name: $tag retained.   New version at\n";
			print "	$final_dst\n";
		}
		else {
			print "$prog_name: overwriting $dst\n";
		}
	}

	copy($src, $final_dst)
		or ExitProgram($options, "failed copy $tag: $!");

	return $final_dst;
}


main();
