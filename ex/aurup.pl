#!/usr/bin/perl

use WWW::AUR::Login;
use POSIX;
use warnings;
use strict;

sub usage
{
    print STDERR "usage: aurup.pl [[category] [file] ...]\n";
    exit 2;
}

sub parsecreds
{
    my($path) = @_;
    open my $f, '<', $path or die "open: $!";
    my($user, $pass);
    if(!defined ($user = <$f>)){
        die "empty username\n";
    }
    if(!defined ($pass = <$f>)){
        die "empty password\n";
    }
    chomp $user;
    chomp $pass;
    close $f;
    return ($user, $pass);
}

sub writecreds
{
    my($path, $user, $pass) = @_;
    print "Storing credentials in $path...\n";
    umask 077;
    open my $f, '>', $path or die "open: $!";
    print $f $user, "\n", $pass, "\n";
    close $f or die "close: $!";
}

sub newlogin
{
    my($user, $pass) = @_;
    my $L = eval { WWW::AUR::Login->new($user, $pass) };
    if($L){ 
        return $L;
    }elsif($@ =~ /bad username or password/){
        print STDERR "error: login failed: bad username or password\n";
        return undef;
    }else{
        print STDERR "error: login failed: $@";
        exit 2;
    }
}

sub prompt
{
    my $ln = '';
    while(length $ln == 0){
        print @_;
        $ln = <STDIN>;
        chomp $ln;
    }
    return $ln;
}

sub echo
{
    my($state) = @_;
    my $t = POSIX::Termios->new();
    $t->getattr(0);
    my $lflag = $t->getlflag;
    if($state eq 'on'){
        $t->setlflag($lflag | POSIX::ECHO);
    }elsif($state eq 'off'){
        $t->setlflag($lflag & ~POSIX::ECHO);
    }else{
        die "invalid parameter: $state";
    }
    $t->setattr(0, &POSIX::TCSANOW);
}

sub login
{
    my($path) = "$ENV{HOME}/.aurup";
    if(-f $path){
        my($user, $pass) = eval { parsecreds($path) };
        if($@){
            print STDERR "error: while reading $path: $@";
        }else{
            my $L = newlogin($user, $pass);
	    return $L if($L);
        }
    }

    ## If file parsing or login fails above, we trickle down to
    ## asking the user interactively.

    for (1 .. 3) {
        my $user = prompt("Username: ");
        echo('off');
	my $pass = prompt("Password: ");
        echo('on');
        print "\n";

        if(my $L = newlogin($user, $pass)){
            writecreds($path, $user, $pass);
            return $L;
        }
    }

    ## Give up after 3 tries to login.

    print "Aborting.\n";
    exit 1;
}

if(@ARGV < 2){
    usage();
}

my $L = login();
while(@ARGV){
    my $cat = shift;
    my $path = shift;
    $L->upload($path, $cat);
}
