#!/usr/bin/perl -w

use strict;
use Test::More tests => 6;
use test_util;

{
    my $output = `PERL5LIB=../src ../src/slack-getroles -C /dev/null --role-list $test_config{'role-list'}`;
    my @output = sort split(/\s+/, $output);
    is_deeply(\@output, \@test_roles, "test config");
}

{
    my $output = `PERL5LIB=../src ../src/slack-getroles -C /dev/null --role-list $test_config{'role-list'} --hostname=fixedhost.example.com`;
    my @output = sort split(/\s+/, $output);
    is_deeply(\@output, ['examplerole'], "hostname override");
}

{
    my $output = `PERL5LIB=../src ../src/slack-getroles -C /dev/null --role-list /dev/null 2> /dev/null`;
    my @output = sort split(/\s+/, $output);
    isnt($?, 0, "no roles exception");
    is_deeply(\@output, [], "no roles output");
}

{
    my $cached_list = "$test_config{'cache'}/_role_list";

    if (-f $cached_list) {
        unlink($cached_list) or die "unlink: $!";
    }
    my $output = `PERL5LIB=../src ../src/slack-getroles -C /dev/null --cache=$test_config{'cache'} --remote-role-list --role-list=$test_config{'role-list'}`;
    my @output = sort split(/\s+/, $output);
    is_deeply(\@output, \@test_roles, "test remote config");
    ok(-f $cached_list, "remote config synced");
    unlink($cached_list) or die "unlink: $!";
}

