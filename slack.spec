Name:		slack
Version:	0.15.2
Release:	1
Summary:	slack configuration management tool
Group:		System Environment/Libraries
License:	GPL
URL:		http://www.sundell.net/~alan/projects/slack/
Source0:	http://www.sundell.net/~alan/projects/slack/%{name}-%{version}.tar.gz
Buildroot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:	noarch
Requires:	rsync >= 2.6.0


%description
configuration management program for lazy admins

slack tries to allow centralized configuration management with a bare minimum
of effort.  Usually, just putting a file in the right place will cause the
right thing to be done.  It uses rsync to copy files around, so can use any
sort of source (NFS directory, remote server over SSH, remote server over
rsync) that rsync supports.


%prep
%setup -q


%build
make


%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/%{_bindir}
%makeinstall libexecdir=%{buildroot}/%{_libdir}


%clean
rm -rf %{buildroot}


%files
%defattr(644,root,root)
%config %{_sysconfdir}/slack.conf
%doc ChangeLog CREDITS COPYING README FAQ TODO doc/slack-intro
%{_mandir}/man1/slack-diff.1.gz
%{_mandir}/man5/slack.conf.5.gz
%{_mandir}/man8/slack.8.gz
%defattr(755,root,root)
%{_bindir}/slack-diff
%{_sbindir}/slack
%{_libdir}/slack
%defattr(0700,root,root)
%{_localstatedir}/lib/slack
%{_localstatedir}/cache/slack

%preun
if [ $1 = 0 ] ; then
    . /etc/slack.conf
    rm -rf "$CACHE"/*
    rm -rf "$STAGE"
fi

%changelog
* Sun Apr 20 2008 Alan Sundell <sundell@gmail.com> 0.15.2-1
- New upstream source (see ChangeLog).
    packaging fixes

* Sat Jan 19 2008 Alan Sundell <alan@sundell.net> 0.15.1-1
- New upstream source (see ChangeLog).
    performance improvement for slack-sync

* Mon Jan 14 2008 Alan Sundell <alan@sundell.net> 0.15.0-1
- New upstream source (see ChangeLog).
    three new options:
      --sleep SECS  (random sleep for crontabs)
      --rsh COMMAND (instead of default ssh; will replace :: syntax in future)
      --version     (print version)
    numerous packaging and installation fixes

* Thu Nov 14 2006 David Lowry <dlowry@bju.edu> 0.14.1-2
- Spec file changes

* Sun Nov 05 2006 Alan Sundell <alan@sundell.net> 0.14.1-1
- New upstream source (see ChangeLog).
    fixes bugs in rsync invocation in slack-getroles

* Thu Oct 12 2006 Alan Sundell <alan@sundell.net> 0.14.0-1
- New upstream source (see ChangeLog).
    new --preview option

* Wed Feb 09 2005 Alan Sundell <alan@sundell.net> 0.13.2-1
- New upstream source (see ChangeLog).
    allows non-existent files dir

* Sat Jan 08 2005 Alan Sundell <alan@sundell.net> 0.13.1-1
- New upstream source (see ChangeLog).
    adds unit tests
    slack-runscript mentions when it skips a non-executable script
        when --verbose is on
    fix bug causing undefined subroutine reference when a backend failed

* Wed Dec 22 2004 Alan Sundell <alan@sundell.net> 0.13-1
- new upstream source (see ChangeLog)
    adds --hostname, --no-sync, --libexec-dir options
    exports root, stage, hostname, verbose to script
        environment
    minor fixes for bugs introduced in 0.12.2

* Tue Dec 21 2004 Alan Sundell <alan@sundell.net> 0.12.2-1
- new upstream source (see ChangeLog)
    moves functions into common library Slack.pm

* Tue Dec 21 2004 Alan Sundell <alan@sundell.net> 0.12.1-1
- new upstream source (see ChangeLog)
    fixes bug introduced in 0.11-1 that broke backups

* Fri Dec 03 2004 Alan Sundell <alan@sundell.net> 0.12-1
- new upstream source (see ChangeLog)
    swap preinstall and fixfiles in order of operations

* Thu Nov 11 2004 Alan Sundell <alan@sundell.net> 0.11-1
- new upstream source (see ChangeLog)
    add --no-files and --no-scripts options

* Fri Oct 29 2004 Alan Sundell <alan@sundell.net> 0.10.2-1
- new upstream source (see ChangeLog)
    use the full role name in the stage

* Fri Oct 29 2004 Alan Sundell <alan@sundell.net> 0.10.1-1
- new upstream source (see ChangeLog)
    minor code cleanups

* Fri Oct 22 2004 Alan Sundell <alan@sundell.net> 0.10-1
- new upstream source (see ChangeLog)
    adds a new "staging" step, which elimates the need for .keepme~ files

* Fri Aug 13 2004 Alan Sundell <alan@sundell.net> 0.7-1
- new upstream source

* Sun Jul 18 2004 Alan Sundell <alan@sundell.net> 0.6-1
- new upstream source

* Sat Jul 17 2004 Alan Sundell <alan@sundell.net> 0.5-1
- new upstream source

* Thu Jul 01 2004 Alan Sundell <alan@sundell.net> 0.4-1
- new upstream source

* Mon May 24 2004 Alan Sundell <alan@sundell.net> 0.1-1
- initial version

