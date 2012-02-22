%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define real_name Rex-Augeas

Summary: Rex-Augeas is an augeas Module for Rex
Name: rex-augeas
Version: 0.2.0
Release: 1
License: Artistic
Group: Utilities/System
Source: http://search.cpan.org/CPAN/authors/id/J/JF/JFRIED/Rex-Augeas-0.2.0.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildRequires: perl-Net-SSH2
BuildRequires: perl >= 5.8.0
BuildRequires: perl(ExtUtils::MakeMaker)
BuildRequires: perl(Config::Augeas)
Requires: perl-Config-Augeas
Requires: rex >= 0.7.0

%description
Rex-Augeas is an augeas Module for (R)?ex.

%prep
%setup -n %{real_name}-%{version}

%build
%{__perl} Makefile.PL INSTALLDIRS="vendor" PREFIX="%{buildroot}%{_prefix}"
%{__make} %{?_smp_mflags}

%install
%{__rm} -rf %{buildroot}
%{__make} pure_install

### Clean up buildroot
find %{buildroot} -name .packlist -exec %{__rm} {} \;


%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root, 0755)
%doc META.yml 
%doc %{_mandir}/*
%{perl_vendorlib}/*

%changelog

* Sat Jun 25 2011 Jan Gehring <jan.gehring at, gmail.com> 0.2.0-1
- changed the api. now you have to name the full augeas path.
- added get action.

* Sat Jun 25 2011 Jan Gehring <jan.gehring at, gmail.com> 0.1.0-1
- inital release


