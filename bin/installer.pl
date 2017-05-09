#!/usr/bin/perl
#  SWAMP SCMS Hooks
#
#  Copyright 2016 Jared Sweetland, Vamshi Basupalli, James A. Kupsch
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
                        help            => 0,
                        version         => 0,
			svn		=> 0,
			git		=> 0,
			print_tools	=> 0,
			print_platforms	=> 0,
			print_projects	=> 0,
			print_packages	=> 0,
			swamp_url	=> "http://mir-swamp.org/",
			force		=> 0,
			post_commit	=> 1,
			post_receive	=> 0
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
			"swamp_url|swamp-url|u=s",
			"force|f",
			"post_commit|post-commit|commit|c",
			"post_receive|post-receive|push|r"
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

	if ($options{print_tools}){
		#system("$options{prog_dir}/bin/uploadPackage.pl --print_tools --main-script $options{prog_dir}/bin/run-main.sh --verbose");
		system("java","-jar","$options{prog_dir}/bin/$options{jar_name}", "login", "-S", "$options{swamp_url}", "-C");
		system("java","-jar","$options{prog_dir}/bin/$options{jar_name}", "tools", "-list");
                exit;
        }
        if ($options{print_platforms}){
		#system("$options{prog_dir}/bin/uploadPackage.pl --print_platforms --main-script $options{prog_dir}/bin/run-main.sh --verbose");
		system("java","-jar","$options{prog_dir}/bin/$options{jar_name}", "login", "-S", "$options{swamp_url}", "-C");
		system("java","-jar","$options{prog_dir}/bin/$options{jar_name}", "platform", "-list");
                exit;
        }
        if ($options{print_projects}){
		#system("$options{prog_dir}/bin/uploadPackage.pl --print_projects --main-script $options{prog_dir}/bin/run-main.sh --verbose");
		system("java","-jar","$options{prog_dir}/bin/$options{jar_name}", "login", "-S", "$options{swamp_url}", "-C");
		system("java","-jar","$options{prog_dir}/bin/$options{jar_name}", "project", "-list");
                exit;
        }
        if ($options{print_packages}){
		#system("$options{prog_dir}/bin/uploadPackage.pl --print_projects --main-script $options{prog_dir}/bin/run-main.sh --verbose");
		system("java","-jar","$options{prog_dir}/bin/$options{jar_name}", "login", "-S", "$options{swamp_url}", "-C");
		system("java","-jar","$options{prog_dir}/bin/$options{jar_name}", "package", "-list");
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
	--help     	  -h print this message
	--version  	  -v print version of $progname
	--svn		  -s specify an svn repository to install the hook
	--git		  -g specify a git repository to install the hook
	--print-tools     -t Displays the available tools to the console
	--print-platforms -p Displays the available platforms to the console
	--print-projects  -j Displays the available projects to the console
	--swamp-url	  -u specify a url for listing packages and updating config files
	--force	  -f overrides any existing files inside your .git/hooks directory on installation
	--post-commit	  -c installs the commit version of the script - commits will trigger uploading (implied with svn)
	--post-receive	  -r installs the push version of the script - receiving a push will trigger uploading (git exclusive)
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
	if (exists $options->{repo} || $options->{repo} eq ""){
		ExitProgram($options, "You must specify a valid repository.");
	}elsif (-e "$options->{repo}/.git" && $options->{git}){
		$options->{repo} = "$options->{repo}/.git";
	}elsif (!(-e "$options->{repo}")){
		ExitProgram($options, "Repository $options->{repo} does not exist.");
	}
	if ($options->{git}){
		unless ($options->{post_receive} || $options->{post_commit}){
			ExitProgram($options, "You must specify either --post-receive or --post-commit with a git repository.\n$!");
		}
	}else{
		unless ($options->{svn}){
			ExitProgram($options, "Please specify whether the specified repository is an svn repository or git repository.\n$!");
		}
	}

	if (!$options->{force}){
		my @existingFiles;
		if(-e "$options->{repo}/hooks/SWAMP_Uploader/uploadPackage.pl"){
			push @existingFiles, "$options->{repo}/hooks/SWAMP_Uploader/bin/uploadPackage.pl";
		}
		if($options->{post_receive} && $options->{git} && -e "$options->{repo}/hooks/post-receive"){
			push @existingFiles, "$options->{repo}/hooks/post-receive";
		}
		if($options->{post_commit} && -e "$options->{repo}/hooks/post-commit"){
			push @existingFiles, "$options->{repo}/hooks/post-commit";
		}
		if(-e "$options->{repo}/hooks/SWAMP_Uploader/$options->{jar_name}"){
                        push @existingFiles, "$options->{repo}/hooks/post-commit";
                }
		if (@existingFiles){
			ExitProgram($options, "Files already installed:\n". join("\n", @existingFiles) ."\nUse the --force flag if you would like to replace them.");
		}
	}

	my $homedir = glob('~');
	if (-e "$options->{repo}/hooks/SWAMP_Uploader"){
		unless (-e "$options->{repo}/hooks/SWAMP_Uploader/uploadConfig.conf"){
			File::Copy::copy "$options->{prog_dir}/config/uploadConfig.template", "$options->{repo}/hooks/SWAMP_Uploader/uploadConfig.conf" or ExitProgram($options, "Could not copy uploadConfig.conf template: $!");
		}
		unless (-e "$options->{repo}/hooks/SWAMP_Uploader/uploadCredentials.conf"){
			File::Copy::copy "$options->{prog_dir}/config/uploadCredentials.template", "$options->{repo}/hooks/SWAMP_Uploader/uploadCredentials.conf" or ExitProgram($options, "Could not copy uploadCredentials.conf template: $!");
		}
		unless (-e "$homedir/.SWAMPUploadConfig.conf"){
			File::Copy::copy "$options->{prog_dir}/config/uploadConfig.template", "$homedir/.SWAMPUploadConfig.conf" or ExitProgram($options, "Could not copy uploadConfig.conf template to home directory $homedir: $!");
		}
		unless (-e "$homedir/.SWAMPUploadCredentials.conf"){
			File::Copy::copy "$options->{prog_dir}/config/uploadCredentials.template", "$homedir/.SWAMPUploadCredentials.conf" or ExitProgram($options, "Could not copy uploadCredentials.conf template to home directory $homedir: $!");
		}
	}else{
		mkdir "$options->{repo}/hooks/SWAMP_Uploader";
		File::Copy::copy "$options->{prog_dir}/config/uploadConfig.template", "$options->{repo}/hooks/SWAMP_Uploader/uploadConfig.conf" or ExitProgram($options, "Could not copy uploadConfig.conf template: $!");
		File::Copy::copy "$options->{prog_dir}/config/uploadCredentials.template", "$options->{repo}/hooks/SWAMP_Uploader/uploadCredentials.conf" or ExitProgram($options, "Could not copy uploadCredentials.conf template: $!");
		File::Copy::copy "$options->{prog_dir}/config/uploadConfig.template", "$homedir/.SWAMPUploadConfig.conf" or ExitProgram($options, "Could not copy uploadConfig.conf template to home directory $homedir: $!");
		File::Copy::copy "$options->{prog_dir}/config/uploadCredentials.template", "$homedir/.SWAMPUploadCredentials.conf" or ExitProgram($options, "Could not copy uploadCredentials.conf template to home directory $homedir: $!");
	}
	File::Copy::copy "$options->{prog_dir}/bin/uploadPackage.pl", "$options->{repo}/hooks/SWAMP_Uploader/" or ExitProgram($options, "Could not copy uploadPackage.pl: $!");
	chmod 0755, "$options->{repo}/hooks/SWAMP_Uploader/uploadPackage.pl";
	File::Copy::copy "$options->{prog_dir}/bin/$options->{jar_name}", "$options->{repo}/hooks/SWAMP_Uploader/" or ExitProgram($options, "Could not copy $options->{jar_name}: $!");
	if ($options->{git}){
		if ($options->{post_commit}){
			File::Copy::copy "$options->{prog_dir}/bin/post-commit.git", "$options->{repo}/hooks/post-commit" or ExitProgram($options, "Could not copy post-commit: $!");
			chmod 0755, "$options->{repo}/hooks/post-commit";
		}
		if ($options->{post_receive}){
			File::Copy::copy "$options->{prog_dir}/bin/post-recieve", "$options->{repo}/hooks/post-receive" or ExitProgram($options, "Could not copy post-receive: $!");
			chmod 0755, "$options->{repo}/hooks/post-receive";
		}
	}else{
		File::Copy::copy "$options->{prog_dir}/bin/post-commit.svn", "$options->{repo}/hooks/post-commit" or ExitProgram($options, "Could not copy post-commit: $!");
	}
}

sub ExitProgram {
	my ($options, $output) = @_;
	print STDERR "$output\n";
	exit 1;
}

main();
