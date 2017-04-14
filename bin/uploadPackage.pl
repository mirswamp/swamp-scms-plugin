#!/usr/bin/perl -w

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
#  limitations under the License.

use strict;
use warnings;
use Archive::Extract;
use Archive::Tar;
use File::Path;
use File::Copy;
use Getopt::Long qw(GetOptionsFromString);
use File::Temp;
use Digest::MD5;
use Digest::SHA;
use Fcntl qw(:DEFAULT :mode :flock);
use Data::Dumper;

my @packageLanguages = ("ActionScript", "Ada", "AppleScript", "Assembly", "Bash", "C", "C#", "C++", "Cobol", "ColdFusion", "CSS", "D", "Datalog", "Erlang", "Forth", "Fortran", "Haskell", "HTML", "Java", "JavaScript", "LISP", "Lua", "ML", "OCaml", "Objective-C", "PHP", "Pascal", "Perl", "Prolog", "Python", "Python-2", "Python-3", "Rexx", "Ruby", "sh", "SQL", "Scala", "Scheme", "SmallTalk", "Swift", "Tcl", "tcsh", "Visual-Basic" );
my @buildSystems = ("android+ant", "android+ant+ivy", "android+gradle", "android+maven", "ant", "ant+ivy", "cmake+make", "configure+make", "gradle", "java-bytecode", "make", "maven", "no-build", "none", "other", "python-distutils");

#Process the user's options and config file
#Returns a pointer to a hash with the options provided
sub ProcessOptions  {

	my $progname = $0;
	$progname =~ s/.*[\\\/]//;

	my $progdir = $0;
	$progdir =~ s/[^\\^\/]+$//;

	my $homedir = glob('~');

	my %optionDefaults = (
			help		=> 0,
			version		=> 0,
			print_tools	=> 0,
			print_platforms	=> 0,
			print_projects	=> 0,
			'config_file'	=> "$progdir/uploadConfig.conf",
			'global_config'	=> "$homedir/.SWAMPUploadConfig.conf",
			'credentials_file'=> "$progdir/uploadCredentials.conf",
			'global_credentials'=> "$homedir/.SWAMPUploadCredentials.conf",
			'log_file'	=> "$progdir/logFile.txt",
			'output_dir'	=> "$progdir/output",
			'package_conf'	=> './package.conf',
			upload		=> 1,
			assess		=> 1,
			program		=> '',
			'commit_info'	=> '/master',
			'run_all_commits'=> 0,
			username	=> '',
			password	=> '',
			tool		=> '',
			project		=> '',
			platform	=> '',
			'new_package_dir'=> '',
			'temp_dir'	=> "$progdir/.tempdir",
			'allowed_branches'=> 'master',
			'main_script'	=> '..scripts/run-main.sh',
			'recover'	=> 0,
			'verify'	=> 0,
			'verbose'	=> 0
			);

	my @options = (
			"help|h",
			"version|v",
			"print_tools|print-tools",
			"print_platforms|print-platforms",
			"print_projects|print-projects",
			"config_file|config-file|c=s",
			"global_config|global-config=s",
			"credentials_file|credentials-file=s",
			"global_credentials|global-credentials=s",
			"log_file|log-file=s",
			"ouptut_file|output-file=s",
			"package_conf|package-conf=s",
			"upload!",
			"assess!",
			"program=s",
			"commit_info|commit-info=s",
			"run_all_commits|run-all-commits!",
			"username|user=s",
			"password|pass=s",
			"tool|t=s",
			"project=s",
			"platform|p=s",
			"new_package_dir|new-package-dir=s",
			"temp_dir|temp-dir=s",
			"allowed_branches|allowed-branches=s",
			"main_script|main-script=s",
			"recover|r",
			"verify",
			"verbose"
				);

	# Configure file options, will be read in this order
	my @confFileOptions = qw/ global_config global_credentials config_file credentials_file /;

	my $programArguments = join " ", @ARGV;
	Getopt::Long::Configure(qw/require_order no_ignore_case no_auto_abbrev/);
	my %getoptOptions;
	my $ok = GetOptions(\%getoptOptions, @options);

	my %options = %optionDefaults;
	my %optSet;
	while (my ($k, $v) = each %getoptOptions)  {
		$options{$k} = $v;
		$optSet{$k} = 1;
	}

	my @errs;

	if ($ok)  {
		foreach my $opt (@confFileOptions)  {
			if (exists $options{$opt})  {
				my $fn = $options{$opt};
				if ($optSet{$opt} || -e $fn)  {
					if (-f $fn)  {
						my $h = ReadConfFile($fn, undef, \@options);

						while (my ($k, $v) = each %$h)  {
							$k =~ tr/-/_/;
							next if $k =~ /^#/;
							$options{$k} = $v;
							$optSet{$k} = 1;
						}
					}  else  {
						push @errs, "option '$opt' option file '$fn' not found";
					}
				}
			}else{
				PrintToLog(\%options,1,"$options{$opt} missing, attempting to run without it...\n");
			}
		}
		while (my ($k, $v) = each %getoptOptions)  {
			$options{$k} = $v;
			$optSet{$k} = 1;
		}
	}

	$options{progname} = $progname;
	$options{progdir} = $progdir;
	$options{homedir} = $homedir;

	if (!$ok || $options{help})  {
		PrintUsage(\%options);
		exit !$ok;
	}

	if ($options{version})  {
		PrintVersion(\%options);
		exit 0;
	}

	if ($options{recover})  {
		Recover(\%options, \@options);
		exit 0;
	}

	if (@errs)  {
	        print STDERR "$0: options Errors:\n    ", join ("\n    ", @errs), "\n";
        	exit 1;
    	}

	unless ($options{verify}){
		InitializeLog(\%options,0);
		PrintToLog(\%options,0,"Options: $programArguments\n");
	}

	verifyOptions(\%options);

	if ($options{verify}){
		print STDERR "No errors found in configuration.\n";
                exit 0;
	}

	return \%options;
}

#Initializes the log and prints a starting message
#Input - a pointer to a hash containing
#            {log_file} - the location to store the log file
#Output - {log_out} - file to be printed to
sub InitializeLog  {

	my ($options, $recovery) = @_;

	if (!$recovery){
		$options->{log_id} = "$options->{commit_info}-".localtime(time);
	}
	$options->{lock_filename} = $options->{log_id};
	$options->{lock_fh} = LockAcquire("$options->{progdir}/$options->{lock_filename}",$recovery);

	if ($options->{lock_fh}){
#		if (-e $options->{log_file}){
#			unlink $options->{log_file};
#		}

		open $options->{log_out}, '>>', $options->{log_file} or die "Can't write new file: $!, stopping at";

		if (!$recovery){

			PrintToLog($options,0,"Upload Package Log File\n");
			if (exists $ENV{GIT_AUTHOR_NAME})  {
				PrintToLog($options,0,"User $ENV{GIT_AUTHOR_NAME}\n");
			}
			if (exists $ENV{GIT_AUTHOR_EMAIL})  {
				PrintToLog($options,0,"Email $ENV{GIT_AUTHOR_EMAIL}\n");
			}
		}
	}else{
		print STDERR "File in use - Recovery will now shut down\n";
		exit 1;
	}
}

#Prints a message to the log file with the date and time
#Input - a pointer to a hash containing
#            {log_out} - the file to be printed to
#      - $error specifies whether the message is an error and should be printed to STDERR
#      - $output the message to be printed
sub PrintToLog  {

	my ($options,$error,$output) = @_;

	unless ($output eq ""){

		if ($error)  {
			print STDERR "$output";
		}

		my @splitOut = split /\n/, $output;
		my $timestamp = localtime(time);

		my $outputFile = $options->{log_out};

		foreach $output (@splitOut)  {
			print $outputFile "[$timestamp][$options->{log_id}]: $output\n";
			if ($options->{verbose})  {
				print STDERR "$output\n";
			}
		}
		flush($outputFile);

#		my $h = select($outputFile);
#		my $af=$|;
#		$|=1;
#		$|=$af;
#		select($h);

	}

}

sub flush {
	my $h = select($_);
	my $af=$|;
	$|=1;
	$|=$af;
	select($h);
}

#Specifies a final message and closes the log
#Input - a pointer to a hash containing
#            {log_out} - the log file to be closed
sub CloseLog  {

	my $options = $_[0];

#PrintToLog($options,0,"End of program.\n");

	my $outputFile = $options->{log_out};
	close $outputFile or die "Could not close log: $!\n";

	LockRelease($options->{lock_fh},"$options->{progdir}/$options->{lock_filename}");

}

sub LockAcquire
{
	my ($lockFile, $nonBlock) = @_;

	my $fh;

	my $r = sysopen($fh, $lockFile, O_CREAT | O_WRONLY);
	if (!$r)  {
		die "sysopen $lockFile: $!";
	}

	my $mode = LOCK_EX;
	$mode |= LOCK_NB if $nonBlock;

	$r = flock($fh, $mode);
	if (!$r)  {
		close $fh or die "close $lockFile: $!";
		if ($nonBlock)  {
			if ($! =~ /unavailable/i)  {
				return undef;
			}
		}
		die "flock $lockFile, LOCK_EX: $!";
	}

	return $fh;
}


sub LockRelease
{
	my ($fh, $lockFile) = @_;

	if (defined $lockFile)  {
		unlink $lockFile or die "unlink $lockFile: $!";
	}
	flock($fh, LOCK_UN) or die "flock $lockFile, LOCK_UN: $!";
	close $fh or die "close $lockFile: $!";
}

#Executes a command safely through the use of arrays
#And returns the STDOUT from that command
#Input - an array containing the commands / options to be executed (in order)
#Output - the output produced by the program (or 0 if an error ocurred)
sub SafeExecute  {

	my $fh_exec;
	open $fh_exec, "-|", @_;
	my $output = "";
	while (<$fh_exec>)  {
		$output = "$output$_";
	}
	close $fh_exec;
	if ($?){
		return 0;
	}
	if ($output eq ""){
		return " ";
	}
	return $output;

}

sub SwampCli {

	my $options = shift @_;
	my $output = SafeExecute("$options->{main_script}",@_);
	return $output;

}

#Verify the validity of the user's input / config file
#Takes in the options from ProcessOptions for verification
sub verifyOptions  {

	my $options = $_[0];

	my $valid = 1;
	unless ($options->{verify}){
		if (-e $options->{credentials_file}){
			my $mode = (stat($options->{credentials_file}))[2] & 07777;
			unless ($mode == 384){
				PrintToLog($options,1,"File permissions for credentials file highly encouraged to be 600 (owner read/write only)\n");
			}
		}else{
			print STDERR "Credentials file at $options->{credentials_file} not found.";
			$valid = 0;
		}

#use Data::Dumper;
#print Dumper(\%options);
		if ($options->{program} eq 'git'){
			$options->{commit_info} =~ s/\s+$//;
			my @temp = split /\//, $options->{commit_info};
			$options->{currentBranch} = $temp[(scalar @temp) - 1];
			my @validBranches = split /\s*,\s*/, $options->{allowed_branches};
			unless (grep {$_ eq $options->{currentBranch}} @validBranches)  {
	
				ExitProgram($options,"This is not a valid branch.\nValid branches are $options->{allowed_branches}\nYou are on branch $options->{currentBranch}\nExiting...\n");
	
			}
		}

#If the config file says not to upload or save a package, do nothing
		unless ($options->{upload} || -e $options->{new_package_dir})  {
			ExitProgram($options,"No upload and no location for package directory. Nothing to do. Exiting...\n");
		}
	}
	unless ($options->{verify} || $options->{program} eq 'git' || $options->{program} eq 'svn')  {
		unless ($options->{print_tools} || $options->{print_platforms} || $options->{print_projects}){
			print STDERR "You must specify if you are using SVN or git by adding the option --program svn or --program git\n";
			$valid = 0;
		}
	}
	if ($options->{username} eq '')  {
		print STDERR "Please include a username=<username> to upload the project.\n";
		$valid = 0;
	}
	if ($options->{password} eq '')  {
		print STDERR "Please include a password=<password> to upload the project.\n";
		$valid = 0;
	}
	unless (-e "$options->{main_script}")  {
		print STDERR "SWAMP-api-client at $options->{main_script} not found.\n";
		$valid = 0;
	}
	if ($valid){
		Login($options);
		$options->{project} = SwampCli($options, "project", "-N", "$options->{project}");
		$options->{project} =~ s/^\s+|\s+$//g;
		if (length $options->{project} != 36)  {
			print STDERR "Project not found: UUID $options->{project} invalid\n";
			$valid = 0;
		}
	}
	if ($valid){
		if ($options->{print_tools}){
			print STDERR SwampCli($options, "tools", "-L");
			print "\n";
			exit;
		}
		if ($options->{print_platforms}){
			print STDERR SwampCli($options, "platform", "-L");
			print "\n";
			exit;
		}
		if ($options->{print_projects}){
			print STDERR SwampCli($options, "project", "-L");
			print "\n";
			exit;
		}
	}
	if ($valid){
		if ($options->{assess}){
			my @toolNames = split(/\s*,\s*/,$options->{tool});
			my @toolUUIDs;
			foreach my $nextTool (@toolNames)  {
				my $nextUUID = SwampCli($options, "tools", "-P", "$options->{project}", "-N", "$nextTool");
				$nextUUID =~ s/^\s+|\s+$//g;
				if (length $nextUUID == 36)  {
					push @toolUUIDs, $nextUUID;
				}else{
					print STDERR "Tool $nextTool not found: UUID $nextUUID invalid\n";
					$valid = 0;
				}
			}
			$options->{tool} = join ',', @toolUUIDs;
		}
		if ($options->{assess})  {
			my @platformNames = split(/\s*,\s*/,$options->{platform});
			my @platformUUIDs;
			foreach my $nextPlatform (@platformNames)  {
				my $nextUUID = SwampCli($options, "platform", "-N", "$nextPlatform");
				$nextUUID =~ s/^\s+|\s+$//g;
				if (length $nextUUID == 36)  {
					push @platformUUIDs, $nextUUID;
				}else{
					print STDERR "Platform $nextPlatform not found: UUID $nextUUID invalid\n";
					$valid = 0;
				}
			}
			$options->{platform} = join ',', @platformUUIDs;
		}
	}
	if (-e $options->{package_conf}){
		my $packageConf = ReadConfFile($options->{package_conf});
		if (!(exists $packageConf->{'package-short-name'}) || $packageConf->{'package-short-name'} eq ""){
			print STDERR "Please specify a package-short-name= in $options->{package_conf}.\n";
	                $valid = 0;
		}
		if (!(exists $packageConf->{'package-language'}) || $packageConf->{'package-language'} eq ""){
			print STDERR "Please specify a valid language in $options->{package_conf}.\n";
			$valid = 0;
		}else{
			my %params = map { $_ => 1 } @packageLanguages;
			unless (exists($params{$packageConf->{'package-language'}})){
				print STDERR "Package language \"$packageConf->{'package-language'}\" is invalid. Please verify you have a valid language in $options->{package_conf}.\n";
	                        $valid = 0;
			}
		}
		if (!(exists $packageConf->{'build-sys'}) || $packageConf->{'build-sys'} eq ""){
			print STDERR "Please specify a valid build system in $options->{package_conf}.\n";
                        $valid = 0;
		}else{
			my %params = map { $_ => 1 } @buildSystems;
			unless (exists $params{$packageConf->{'build-sys'}}){
				print STDERR "Build system \"$packageConf->{'build-sys'}\" is invalid. Please verify you have a valid build system in $options->{package_conf}.\n";
	                        $valid = 0;
			}
		}
		if (exists $packageConf->{'build-file'} and !(-e "$packageConf->{'build-dir'}/$packageConf->{'build-file'}")){
                        print STDERR "Build file $packageConf->{'build-dir'}/$packageConf->{'build-file'} not found.\n";
                        $valid = 0;
                }
	}else{
		print STDERR "$options->{package_conf} does not exist.\n";
		$valid = 0;
	}
	unless ($valid)  {
		unless ($options->{verify}){
			CloseLog($options);
		}
		exit 1;
	}
}

#Displays the help menu for the program
sub PrintUsage  {
	my $options = $_[0];

# the message below should use spaces not tabs, so it formats correctly
# if the user has tab stops set to something other than 8.
	print STDERR <<EOF;
Usage: $options->{progname} --options <arguments>...

Adds packages to SWAMP and runs assessments.
Options overrides configuration file, configuration file overrides defaults.
Use full paths for any directories
   options:
       --help             -h print this message
       --version          -v print version of $options->{progname}
       --print-tools         Displays the available tools to the console
       --print-platforms     Displays the available platforms to the console
       --print-projects      Displays the available projects to the console
       --log-file            output file for log - default = $options->{progdir}/logFile.txt
       --config-file      -c config file location - default = $options->{progdir}/uploadConf.conf
       --global-config       global config file location - default = $options->{homedir}/.SWAMPUploadConf.conf
       --credentials-file    credentials file location - default = $options->{progdir}/uploadCredentials.conf
       --global-credentials  global credentials file location - default = $options->{homedir}/SWAMPUploadCredentials.conf
       --output-dir          location to place the assessment results
       --package-conf        directory/name of the package.conf file from the repository - default ./package.conf
       --username	     use a username for logging in
       --password            use a password for logging in
       --main-script         directory to main script of the swamp-api-client - default = scripts/run-main.vm
       --tool             -t use tools for assessment (separated by commas)
       --project             choose the project that the package will be uploaded to
      [--platform]        -p use specific platforms for assessment (separated by commas) - OPTIONAL
      [--noupload]           will not upload the package - default will upload (set upload=0 in config file for no upload or assess)
      [--noassess]           will only upload the package - default will assess (set assess=0 in config file for no assess)
      [--new-package-dir]    create an additional folder in the specified directory that contains your archived package and a corresponding package.conf file
       --temp-dir            specify where the program should store temporary files that will be deleted as the program exits - default = $options->{progdir}/.tempdir
       --allowed-branches    specify the branches that will be run - default only allows the master branch
       --run-all-commits     specify whether you want every commit since the last push to all be uploaded and assessed - default will only run the most recent (set run-all-commit=1 in the config file)
       --verbose             prints out additional output for debugging use or for updates on where the program is while running
       --recovery            enters recovery mode - checks log for any incomplete runs and completes them - does not submit anything if no recovery is needed
       --verify              validates package.conf file and uploadConfig.conf file without uploading or assessing the package

You can specify allowed branches in the config file by adding allowed-branches=<branches separated by commas> - default = only the master branch

A standard config file will be something like this:

   username=steve
   password=password123
   tool=163f2b01-156e-11e3-a239-001a4a81450b
   project=9cf9652b-29aa-11e6-a8c0-001a4a814505
   platform=48f9a9b0-976f-11e4-829b-001a4a81450b
   run-all-commits=1
   allowed-branches=master,branch01,branch02,branch03
   main-script=scripts/run-main.sh
   new-package-dir=./
   #Comments are ignored

EOF
}

sub PrintVersion  {
	my $options = $_[0];

	print STDERR "$options->{progname} version 0.7.1\n";
}

#Login to the server
#Arguments - A pointer to a hash with:
#    a directory to the swamp-api (swampDir)
#    a username for logging in (username)
#    a password for logging in (password)
#Exits if the login was unsuccessful
sub Login  {

	my $options = $_[0];

#	chdir $options->{swamp_api} or ExitProgram($options,"Could not change directories: $!\n");

	my $template = "TEMP_USR_XXXXXX";
	unless (-e $options->{temp_dir}){
		mkdir $options->{temp_dir};
	}
	my ($fh, $filename) = File::Temp::tempfile($template, DIR => $options->{temp_dir}, UNLINK => 1) or ExitProgram($options,"Could not create temporary credentials file: $!\n");

	unless ($options->{verify}){
		PrintToLog($options,0,"Temporary Filename: $filename\n");
	}

#Permissions for File::Temp ar automally set to read/write user only
	print $fh "USERNAME=$options->{username}\nPASSWORD=$options->{password}\n";
	flush ($fh);

#print "sleeping\n";
#    sleep 30;
#print "done\n";

	my $output = SwampCli($options, "login", "--filepath", "$filename", "-S", "https://www.mir-swamp.org");
	close $fh;
	unless ($output){
		unlink "$filename" or ExitProgram($options,"Could not remove temporary credentials file: $!\nLogin failed: Check your username and password.\n");
		ExitProgram($options,"Login failed: Check your username and password. $!\n");
	}
	unlink "$filename" or ExitProgram($options,"Could not remove temporary credentials file: $!\n");

}

#Uploads and assesses the package given
#Arguments - a pointer to a hash with:
#    the directory of the archive file {archive_file}
#    the directory of the package.conf file {conf_file}
#    the id for the project for the package to go in {project}
#    the option to assess the package {assess}
#    the tool id for the assessment {tool}
#    the platform for the assessment {platform} [optional]
sub UploadPackage  {

	my $options = $_[0];

	PrintToLog($options,0,"Uploading package\n");

#print "Sleeping before package is uploaded\n";
#sleep 5;
#print "Awake\n";

	my $packageID = SwampCli($options, "package", "--quiet", "--pkg-archive", $options->{archive_file}, "--pkg-conf", $options->{conf_file}, "--project-uuid", $options->{project});

#print "Sleeping after package was uploaded\n";
#sleep 5;
#print "Awake\n";

	unless ($packageID){
		ExitProgram($options,"Upload failed: $!\n");
	}
	PrintToLog($options,0,"Package UUID: $packageID\n");

	AssessPackage($options, $packageID);

}

sub AssessPackage {

	my ($options,$packageID) = @_;

	if ($options->{assess})  {
		my @toolIDs = split(/\s*,\s*/,$options->{tool});

		my $nextTool;
		foreach $nextTool (@toolIDs)  {

			my $assessResults;

			if ($options->{platform} eq '')  {

				PrintToLog($options,0,"Tool: $nextTool\nRunning Assessment\n");

#print "Sleeping on tool $nextTool\n";
#sleep 5;
#print "Awake\n";

				$assessResults = SwampCli($options, "assess", "--run-assess", "--quiet", "--pkg-uuid", $packageID, "--project-uuid", $options->{'project'}, "--tool-uuid", $nextTool);

				if (!$assessResults){
					ExitProgram($options,"Assessment failed! $!\n");
				}

				PrintToLog($options,0,"Assessment ID: $assessResults");
				my @assessList;
				my $tempList;
				if (exists $options->{assess_list}){
					$tempList = $options->{assess_list};
					@assessList = @$tempList;
				}else{
					$options->{assess_list} = \@assessList;
				}
				push @assessList, $assessResults;
				$options->{assess_list} = \@assessList;

			}else{

				my @platformIDs = split(/\s*,\s*/,$options->{platform});

				my $nextPlatform;

				AssessOnPlatforms($options,$packageID,$nextTool);

			}
		}
	}
}

sub AssessOnPlatforms {

	my ($options,$packageID,$toolID) = @_;

	my @platformIDs = split(/\s*,\s*/,$options->{platform});
	my $nextPlatform;
	my $assessResults;

	PrintToLog($options,0,"Tool: $toolID\n");
	foreach $nextPlatform (@platformIDs)  {

		PrintToLog($options,0,"Platform: $nextPlatform\nRunning Assessment on Platforms\n");

#print "Sleeping on platform $nextPlatform\n";
#sleep 5;
#print "Awake\n";

		$assessResults = SwampCli($options, "assess", "--run-assess", "--quiet", "--pkg-uuid", $packageID, "--project-uuid", $options->{'project'}, "--tool-uuid", $toolID, "--platform-uuid", $nextPlatform);

		if (!$assessResults){
			ExitProgram($options,"Assessment failed! $!\n");
		}

		PrintToLog($options,0,"Assessment ID: $assessResults");
		my @assessList;
		my $tempList;
		if (exists $options->{assess_list}){
			$tempList = $options->{assess_list};
			@assessList = @$tempList;
		}else{
			$options->{assess_list} = \@assessList;
		}
		push @assessList, $assessResults;
		$options->{assess_list} = \@assessList;

	}

}

#Rewrites the config file to update the tar file, the sha512, and the md5
#Arguments - a pointer to a hash with:
#    the directory of the archive file {archive_file}
#    the directory of the package.conf file {conf_file}
sub UpdateConf  {

	my ($options,$nextCommit) = @_;

	my $sha512 = unpack("H*", Digest::SHA::sha512($options->{archive_file}));
	my $md5 = unpack("H*", Digest::MD5::md5($options->{archive_file}));

	my $confOptions = ReadConfFile($options->{conf_file});

	unless (exists $options->{package_name} && exists $options->{package_version}){
		ExitProgram($options,"Not enough arguments in package.conf, please include a package-short-name and package-version.");
	}

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
#$confOptions->{"package-version"} = sprintf ("$options->{package_version}-Date:%02d/%02d/%02d,%02d:%02d:%02d-Commit:$nextCommit",$year,$mon,$mday,$hour,$min,$sec);
	$confOptions->{"package-version"} = "$options->{package_version}";
	$confOptions->{"package-short-name"} = "$options->{package_name}";
	$confOptions->{"package-archive"} = "$options->{package_name}-$options->{package_version}.tar";
	$confOptions->{"package-archive-md5"} = $md5;
	$confOptions->{"package-archive-sha512"} = $sha512;

	open my $out, '>', "$options->{conf_file}new" or ExitProgram($options, "Can't write new file: $!\n");

	my @keys = keys %$confOptions;
	my @values = values %$confOptions;
	while (@keys)  {
		print $out pop(@keys)."=".pop(@values)."\n";
	}

	unlink $options->{conf_file} or ExitProgram($options,"Could not update conf file: $!\n");
	rename "$options->{conf_file}new",$options->{conf_file} or ExitProgram($options,"Could not update conf file: $!\n");

}

sub HasValue  {
	my ($s) = @_;

	return defined $s && $s ne '';
}

#Reads a config file and returns a hash with its values
#Arguments - the name of the config file to be read
#Returns the address to a hash with the configurations specified by the file
sub ReadConfFile  {
	my ($filename, $required) = @_;
	my $lineNum = 0;
	my $colNum = 0;
	my $linesToRead = 0;
	my $charsToRead = 0;
	my %h;
	$h{'#filenameofconffile'} = $filename;

	open my $confFile, "<$filename" or die "Open configuration file '$filename' failed: $!\n";
	my ($line, $k, $kLine, $err);
	while (1)  {
		if (!defined $line)  {
			$line = <$confFile>;
			last unless defined $line;
			++$lineNum;
			$colNum = 1;
		}

		if ($linesToRead > 0)  {
			--$linesToRead;
			chomp $line if $linesToRead == 0;
			$h{$k} .= $line;
		}  elsif ($charsToRead > 0)  {
			my $v = substr($line, 0, $charsToRead, '');
			$colNum = length $v;
			$charsToRead -= $colNum;
			$h{$k} .= $v;
			redo if length $line > 0;
		}  elsif ($line !~ /^\s*(#|$)/)  {
# line is not blank or a comment (first non-whitespace is a '#')
			if ($line =~ /^\s*(.*?)\s*(?::([^:]*?))?=(\s*(.*?)\s*)$/)  {
				my ($u, $wholeV, $v) = ($2, $3, $4);
				$k = $1;
				$kLine = $lineNum;
				if ($k eq '')  {
					chomp $line;
					$err = "missing key, line is '$line'";
					last;
				}
				if (!defined $u)  {
# normal 'k = v' line
					$h{$k} = $v;
				}  else  {
# 'k :<COUNT><UNIT>= v' line
					$u = '1L' if $u eq '';
					if ($u =~ /^(\d+)L$/i)  {
						$linesToRead = $1;
					}  elsif ($u =~ /^(\d+)C$/i)  {
						$charsToRead = $1;
						$colNum = length($line) - length($wholeV);
					}  else  {
						$err = "unknown units ':$u='";
						last;
					}
					$h{$k} = '';
					$line = $wholeV;
					redo;
				}
			}  else  {
				chomp $line;
				$err = "bad line (no '='), line is '$line'";
				last;
			}
		}
		undef $line;
	}
	close $confFile or defined $err or die "Close configuration file '$filename' failed: $!\n";

	if (defined $err)  {
		my $loc = "line $lineNum";
		$loc .= " column $colNum" unless $colNum == 1;
		die "Configuration file '$filename' $loc $err";
	}

	if ($linesToRead > 0)  {
		die "Configuration file '$filename' missing $linesToRead lines for key '$k' at line $kLine";
	}

	if ($charsToRead > 0)  {
		die "Configuration file '$filename' missing $charsToRead characters for key '$k' at line $kLine";
	}

	if (defined $required)  {
		my @missing = grep { !HasValue $h{$_}; } @$required;
		if (@missing)  {
			die "Configuration file '$filename' missing required keys: " . join(", ", @missing);
		}
	}

	return \%h;
}

#Creates an archive from the repository, uploads and assesses that archive, and then removes the archive
#Input - $options is a pointer to a hash containing:
#            {repo-dir} - directory of the repository
#            {swamp-api} - directory of the swamp-api
#            {upload} - whether the package should be uploaded
#                if enabled, all input to UploadPackage is needed as well
#      - $nextCommit is the commit to create the archive for
#Output - options->{archive-file} contains the location of the archive file
#       - options->{conf-file} contains the location of the configuration file from the package
sub MakeArchive {

	my $options = shift @_;

	if ($options->{program} eq "git"){

		my $nextCommit = shift @_;

		my $redoArchive = 1;
		my $numRetries = 0;

		while ($redoArchive){
			$redoArchive = 0;
			if ($_[0]){
				PrintToLog($options,0,"Requesting archive of $nextCommit\n");
			}
#Create an archive for the project to be uploaded to the swamp
#			chdir $options->{repo_dir} or ExitProgram($options,"Could not move to the git directory: $!\n");
			SafeExecute("git", "archive", $nextCommit, "-o", "tempName.tar") or ExitProgram($options,"Could not get git archive: $!\n");

			$options->{archive_file} = "$options->{repo_dir}/tempName.tar";
			my $tempFile = "$options->{temp_dir}/.archiveTemp";
			if (-e "$tempFile")  {
				File::Path::rmtree "$tempFile" or ExitProgram($options,"Could not remove $tempFile for archive use: $!\n");
			}
			my $archiveFile = Archive::Extract->new( archive => "$options->{archive_file}" ) or $redoArchive = 1;

			$archiveFile->extract( to => "$tempFile" ) or $redoArchive = 1;

			if ($redoArchive){
				$numRetries++;
				if ($numRetries > 2){
					ExitProgram($options,"Faild to archive project after $numRetries tries: $!");
				}else{
					print STDERR "Could not get archive of project: $!\nRetrying\n";
				}
			}

			$options->{conf_file} = "$tempFile/$options->{package_conf}";

		}

#Rename the archive to match the name of the program
		my $packageConf = ReadConfFile($options->{conf_file});
		$options->{package_name} = $packageConf->{'package-short-name'};
		$options->{package_version} = $packageConf->{'package-version'};
		rename "$options->{archive_file}","$options->{temp_dir}/$options->{package_name}-$options->{package_version}.tar";
		$options->{archive_file} = "$options->{temp_dir}/$options->{package_name}-$options->{package_version}.tar";

	}elsif ($options->{program} eq "svn"){

#Create an archive for the project to be uploaded to the swamp
		if ($_[1]){
			PrintToLog($options,0,"Requesting archive\n");
		}

#		chdir $options->{repo_dir};
		SafeExecute("svn", "export", "File://$options->{temp_dir}", ".archiveTemp/", "--force") or ExitProgram($options,"Could not export svn trunk: $!\n");

		move ("$options->{temp_dir}/.archiveTemp/trunk/$options->{package_conf}","$options->{temp_dir}/package.conf") or ExitProgram($options,"Could not find package.conf in $options->{temp_dir}/.archiveTemp/trunk/$options->{package_conf}, $!\n");
		$options->{conf_file} = "$options->{repo_dir}/package.conf";
		my $packageConf = ReadConfFile($options->{conf_file});
		$options->{package_name} = $packageConf->{'package-short-name'};
		$options->{package_version} = $packageConf->{'package-version'};

#		chdir ".archiveTemp/trunk/$options->{package_dir}" or ExitProgram($options, "Could not find package-dir $options->{package_dir}. $!");
		Archive::Tar->create_archive("$options->{temp_dir}/$packageConf->{package_short_name}-$packageConf->{package_version}.tar", COMPRESS_GZIP, glob "*") or ExitProgram($options,"Could not create tar from trunk: $!\n");
		$options->{archive_file} = "$options->{temp_dir}/$packageConf->{package_short_name}-$packageConf->{package_version}.tar";
#		chdir $options->{swamp_api};
		File::Path::rmtree "$options->{temp_dir}/.archiveTemp";

	}
}

#Removes / moves temporary package files
#Input - an address to a hash with:
#     {repo-dir} Location of temporary package files
#     {new-package-dir} Location for the new package to be stored
#     {package-name} Name of the package
#     {package-version} Version of the package
#     {archive-file} Location of the archive file to be deleted
#     {config-file} Location of the config file to be deleted
sub RemoveTempPackage {
	my $options = $_[0];
#Move the archive and package.conf file into one spot if desired
	if (-e $options->{new_package_dir})  {
		PrintToLog($options,0,"Creating package at $options->{temp_dir}/$options->{new_package_dir}/$options->{package_name}-$options->{package_version}\n");
		mkdir "$options->{new_package_dir}/$options->{package_name}-$options->{package_version}" or print STDERR "Could not create a new package: $!\n";
		move ("$options->{temp_dir}/$options->{archive_file}","$options->{new_package_dir}/$options->{package_name}-$options->{package_version}/");
		move ("$options->{temp_dir}/$options->{conf_file}","$options->{new_package_dir}}$options->{package_name}-$options->{package_version}/package.conf");
		$options->{archive_file} = "$options->{new_package_dir}/$options->{package_name}-$options->{package_version}/$options->{package_name}-$options->{package_version}.tar";
		$options->{conf_file} = "$options->{new_package_dir}/$options->{package_name}-$options->{package_version}/package.conf";
	}else{
		unlink "$options->{temp_dir}/$options->{archive_file}";
		unlink "$options->{temp_dir}/$options->{conf_file}";
		if ($options->{new_package_dir} ne '')  {
			ExitProgram($options,"$options->{new_package_dir} does not exist. Cannot create new package folder.\n");
		}
	}
	File::Path::rmtree "$options->{temp_dir}/.archiveTemp";

}

#Searches the revision log to find all commits between the provided input or the current commit
#Input - an address to a hash with:
#     {commit_info} containing the two commits to find separated by a space
#     {run-all-commits} with a boolean on whether it should only run the current commit or all of them
#     {currentBranch} the newest commit's branch
#Output - returns a list of the git ID's
sub AccessCommits  {

	my $options = $_[0];
	my @commitLog;
	if ($options->{program} eq 'git'){
		if ($options->{run_all_commits} && $options->{commit_info} ne "/master")  {
			my $logStart = (split / /,$options->{commit_info})[0];
			my $logEnd = (split / /,$options->{commit_info})[1];

#			chdir "$options->{repo_dir}/";
			my $commitLog = SafeExecute("git", "log", "$logStart..$logEnd", "--format=format:%H") or ExitProgram($options,"Could not receive a git log for each commit: $!\n");

			@commitLog = split (/\n/,$commitLog);

		}else{
#			chdir "$options->{repo_dir}/";
			push @commitLog, SafeExecute("git", "rev-parse", "HEAD");
			$commitLog[0] =~ s/\s+$//;
		}
	}elsif($options->{program} eq 'svn'){
		push @commitLog, "$options->{commit_info}";
	}
	return @commitLog;
}

#Exits the program, printing an exit message and removing any remaining temporary files
#Input - pointer to a hash containing:
#            {repo_dir} - location of the svn workspace to delete temporary directory .archiveTemp/
#            {archive_file} - location of the archive file to delete
#            {'upload'} - whether a package was uploaded to determine if the user logged in
#                    -if the user did log in, {swamp_api} and {main_script} to allow the user to log out
#      - a message containing the exit error
sub ExitProgram {

	my ($options,$message) = @_;

	print STDERR "$message";

	if (-e "$options->{temp_dir}/.archiveTemp")  {
		File::Path::rmtree "$options->{temp_dir}/.archiveTemp";
	}
	if (exists $options->{archive_file} && -e $options->{archive_file})  {
		unlink $options->{archive_file};
	}
	if ($options->{'upload'})  {
#		chdir $options->{swamp_api};
		SwampCli($options, "logout");
	}

	LockRelease($options->{lock_fh},"$options->{progdir}/$options->{lock_filename}");
#CloseLog($options);
	die;

}

#Prints out all the assessments that were run during the program
#Input - pointer to a hash containing:
#            {output-dir} - location to place output files
#            {swamp-api} - location of swamp api
#            {main-script} - location of main script from swamp api
#            {assess-list} - pointer to list of all assessment uuids
#            {project} - project uuid
sub PrintAssess {
	my $options = $_[0];

	unless (-e $options->{output_dir}){
		mkdir $options->{output_dir};
	}

#	chdir $options->{swamp_api};

	PrintToLog($options,0,"Getting output from assessments\n");
	my $nextAssess;
	my $listTemp = ($options->{assess_list});
	my @assessList = @$listTemp;
	foreach $nextAssess (@assessList)  {

		my $results = "";
		my $previousResults = "";
		while(!$results){

			$results = SwampCli($options, "status", "-A", "$nextAssess", "-P", "$options->{project}");
			if (!$results){
				ExitProgram($options,"Could not get results from $nextAssess: $!\n");
			}elsif (substr ($results,0,10) eq "Finished, ")  {
				$results = substr ($results,10);
				$results =~ s/\s+$//;
				print "Outputting results of $results\n";
			}else{
				unless ($results eq $previousResults){
					print "Waiting on result of $nextAssess\nProgress: $results";
					$previousResults = $results;
				}
				sleep 30;
				$results = "";
			}

		}

		SwampCli($options, "results", "-R", "$results", "-P", "$options->{project}", "-F", "$options->{output_dir}/Result_$nextAssess") or ExitProgram($options, "Could not retrieve results from $results: $!\n");
		print "Results of $nextAssess are available at $options->{output_dir}/Result_$nextAssess\n";

	}
}

#Resumes the system where it left off based on the log files
sub Recover {

	my ($options,$optArray) = @_;

	open (DATA, "$options->{log_file}") or die "Could not find log file $options->{log_file}\nStopping";
	my %recoveryHash;
	my @recoveryIDs;
	while (<DATA>) {
		my $nextLine = substr ((split(/]/,$_))[2], 2);
		my $logID = substr ((split(/]/,$_))[1], 1);
		my %params = map { $_ => 1 } @recoveryIDs;
		unless(exists $params{$logID}) {
			push @recoveryIDs, $logID;
		}
		$recoveryHash{"$logID-lastLine"} = $nextLine;
		if (substr ($nextLine, 0, 9) eq "Options: "){
			$recoveryHash{"$logID-programArguments"} = substr ($nextLine, 9);
		}
		if (substr ($nextLine, 0, 13) eq "Directory is "){
			$options->{repo_dir} = substr ($nextLine, 13);
			$options->{repo_dir} =~ s/\s+$//;
		}
		if (substr ($nextLine, 0, 20) eq "Temporary Filename: "){
                        $recoveryHash{"$logID-tempFile"} = substr ($nextLine, 20);
                        $recoveryHash{"$logID-tempFile"} =~ s/\s+$//;
                }
		if (substr ($nextLine, 0, 22) eq "Requesting archive of "){
			$recoveryHash{"$logID-nextCommit"} = substr ($nextLine, 22);
			$recoveryHash{"$logID-nextCommit"} =~ s/\s+$//;
		}
		if (substr ($nextLine, 0, 14) eq "Package UUID: "){
			$recoveryHash{"$logID-nextPackage"} = substr ($nextLine, 14);
			$recoveryHash{"$logID-nextPackage"} =~ s/\s+$//;
		}
		if (substr ($nextLine, 0, 6) eq "Tool: "){
			$recoveryHash{"$logID-nextTool"} = substr ($nextLine, 6);
			$recoveryHash{"$logID-nextTool"} =~ s/\s+$//;
		}
		if (substr ($nextLine, 0, 10) eq "Platform: "){
			$recoveryHash{"$logID-nextPlatform"} = substr ($nextLine, 10);
			$recoveryHash{"$logID-nextPlatform"} =~ s/\s+$//;
		}
		if (substr ($nextLine, 0, 15) eq "Assessment ID: "){
			my $index;
			if (exists $recoveryHash{"$logID-assessmentListLength"}){
				$index = $recoveryHash{"$logID-assessmentListLength"};
			}else{
				$index = 0;
				$recoveryHash{"$logID-assessmentListLength"} = $index;
			}
			$recoveryHash{"$logID-assessmentList$index"} = substr ($nextLine, 15);
			$recoveryHash{"$logID-assessmentList$index"} =~ s/\s+$//;
			$recoveryHash{"$logID-assessmentListLength"}++;
		}
	}
	my $nextRecoveryCommit;
	$options->{log_id} = $recoveryIDs[0];
	InitializeLog($options,1);
	
	foreach $nextRecoveryCommit (@recoveryIDs)  {
		$options->{log_id} = $nextRecoveryCommit;

		my $lastLine = $recoveryHash{"$nextRecoveryCommit-lastLine"};
		my $programArguments = $recoveryHash{"$nextRecoveryCommit-programArguments"};
		GetOptionsFromString($programArguments,$options, @$optArray);
		my $nextCommit = $recoveryHash{"$nextRecoveryCommit-nextCommit"};
		my $nextPackage =  $recoveryHash{"$nextRecoveryCommit-nextPackage"};
		my $nextTool = $recoveryHash{"$nextRecoveryCommit-nextTool"};
		my $nextPlatform = $recoveryHash{"$nextRecoveryCommit-nextPlatform"};
		my @assessmentList;
		for (my $i = 0; exists $recoveryHash{"$nextRecoveryCommit-assessmentList$i"}; $i++){
			push @assessmentList, $recoveryHash{"$nextRecoveryCommit-assessmentList$i"};
		}

		if ($lastLine eq "End of program.\n"){
print STDERR "Commit $nextCommit: No recovery necessary\n";
			next;
		}

		if (-e $recoveryHash{"$nextRecoveryCommit-tempFile"}){
			unlink $recoveryHash{"$nextRecoveryCommit-tempFile"};
		}
		if ($lastLine eq "Initializing\n" || substr ($lastLine, 0, 18) eq "Requesting archive" || substr ($lastLine, 0, 20) eq "Temporary Filename: "){
			eval {
				main($options);
			};
			next;
		}
		if ($lastLine eq "Getting output from assessments\n")  {
			eval {
#				chdir $options->{swamp_api};
				Login ($options);
#PrintAssess($options);
				PrintToLog($options,0,"Logging out\n");
				SwampCli($options, "logout") or ExitProgram($options,"Could not log out: $!\n");
				PrintToLog($options,0,"End of program.\n");
			};
			next;
		}

		eval {
#			chdir $options->{swamp_api};
			Login($options);

			my @commitLog = AccessCommits($options);
			if ($options->{program} eq 'git'){
				while (shift (@commitLog) ne $nextCommit){
					if (scalar @commitLog == 0){
						ExitProgram($options,"Recovery failure: Git Commit $nextCommit not found.\n");
					}
				}
			}

			MakeArchive($options,$nextCommit,0);
			UpdateConf($options,$nextCommit);

			if ($lastLine eq "Uploading package\n"){

				PrintToLog($options,0,"Searching for package in case it was uploaded\n");
#				chdir $options->{swamp_api};
				my @packageList = split (/\n\n/, SwampCli($options, "package", "--list"));
				my $packageMatch = 0;
				while (@packageList) {
					my $nextPackage = shift @packageList;
					if ($nextPackage =~ /$options->{package_name}/){
						my @packageVersions = split (/\n/, $nextPackage);
						while (@packageVersions) {
							my $nextVersion = shift @packageVersions;
							if ($nextVersion =~ /\t$options->{package_version} /){
								$packageMatch = substr($nextVersion, -38,36);
							}
						}
					}
				}

				if ($packageMatch){
					AssessPackage($options,$packageMatch);
				}else{
					UploadPackage($options);
				}
				RemoveTempPackage($options);
			}

			if ($lastLine eq "Running Assessment\n"){

				my $tempTools = $options->{tool};
				my @toolIDs = split(/\s*,\s*/,$options->{tool});
				while ($toolIDs[0] ne $nextTool){
					shift (@toolIDs);
					if (scalar @toolIDs == 0){
						ExitProgram($options,"Recovery failure: Tool $nextTool not found.\n");
					}
				}
				$options->{tool} = join (",", @toolIDs);
#				chdir $options->{swamp_api};
				AssessPackage($options,$nextPackage);
				RemoveTempPackage($options);
				$options->{tool} = $tempTools;

			}

			if ($lastLine eq "Running Assessment on Platforms\n"){

				my $tempPlatforms = $options->{platform};
				my @platformIDs = split(/\s*,\s*/,$options->{platform});
				while ($platformIDs[0] ne $nextPlatform){
					shift (@platformIDs);
					if (scalar @platformIDs == 0){
						ExitProgram($options,"Recovery failure: Platform not found.\n");
					}
				}
				$options->{platform} = join (",", @platformIDs);
#				chdir $options->{swamp_api};
				AssessOnPlatforms($options,$nextPackage,$nextTool);
				$options->{platform} = $tempPlatforms;
				my $tempTools = $options->{tool};
				my @toolIDs = split(/\s*,\s*/,$options->{tool});
				while (shift (@toolIDs) ne $nextTool){
					if (scalar @toolIDs == 0){
						ExitProgram($options,"Recovery failure: Tool $nextTool not found.\n");
					}
				}
				$options->{tool} = join (",", @toolIDs);
				AssessPackage($options,$nextPackage);
				RemoveTempPackage($options);
				$options->{tool} = $tempTools;

			}

			foreach $nextCommit (@commitLog)  {

				$nextCommit = substr $nextCommit,0,7;
				MakeArchive($options,$nextCommit,0);

				if ($options->{upload})  {

#					chdir $options->{swamp_api};
					UpdateConf($options,$nextCommit);
					UploadPackage($options);

				}
				RemoveTempPackage($options);
			}

			if ($options->{upload})  {
#				chdir $options->{swamp_api};
				if ($options->{assess}){
#PrintAssess($options);
				}
				PrintToLog($options,0,"Logging out\n");
				SwampCli($options, "logout") or ExitProgram($options,"Could not log out: $!\n");
				PrintToLog($options,0,"End of program.\n");
			}
		};
	}
	CloseLog($options);
}

#Executes the commands in order
sub main  {

	my $options;
	if (exists $_[0]){
		$options = $_[0];
	}else{
		$options = ProcessOptions();

		$options->{repo_dir} = `pwd`;
		$options->{repo_dir} =~ s/\s+$//;
	}

	PrintToLog($options,0,"Directory is $options->{repo_dir}\n");
	PrintToLog($options,0,"Initializing\n");
	my @commitLog = AccessCommits($options);

	if ($options->{upload})  {

		Login($options);

#        if ($options->{assess} && $options->{platform} eq '')  {
#
#            PrintToLog($options,0,"-----\nNo platform found. If you would like to add one, here are your options:\n-----\n");
#            PrintToLog($options,0,(SwampCli($options, "platform", "--list") or PrintToLog($options,0,"Options not available: $!\n")));
#
#        }

	}

#If we need to get all the commits in a push, retrieve all sha's needed
	my $nextCommit;
	foreach $nextCommit (@commitLog)  {

		MakeArchive($options,$nextCommit,1);

		if ($options->{upload})  {

#			chdir $options->{swamp_api};
			UpdateConf($options,$nextCommit);

			UploadPackage($options);

		}

		RemoveTempPackage($options);

	}

	if ($options->{upload})  {

#		chdir $options->{swamp_api};
		if ($options->{assess}){
#PrintAssess($options);
		}
		PrintToLog($options,0,"Logging out\n");
		SwampCli($options, "logout") or ExitProgram($options,"Could not log out: $!\n");

	}

	PrintToLog($options,0,"End of program.\n");
	CloseLog($options);

}

main();
