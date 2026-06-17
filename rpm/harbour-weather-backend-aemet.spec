Name:       harbour-weather-backend-aemet
Summary:    AEMET weather provider for Sailfish Weather
Version:    1.3.2
Release:    2
License:    BSD-3-Clause
BuildArch:  noarch
URL:        https://github.com/juanro49/harbour-weather-backend-aemet
Source0:    https://github.com/juanro49/%{name}/archive/refs/tags/v%{version}.tar.gz
Requires:   sailfish-components-weather-qt5 >= 1.3.2

%description
This package provides an external weather backend for Sailfish Weather using
the AEMET OpenData API (https://opendata.aemet.es/).
It includes automatic coordinate to municipality mapping using CartoCiudad.

%prep
%setup -q -n %{name}-%{version}

%build
# Generate the JS translation dictionary from .ts files
python3 scripts/generate_translations.py

%install
# Install the QML backend
mkdir -p %{buildroot}%{_datadir}/sailfish-weather/backends
install -p -m 644 backends/AEMETBackend.qml %{buildroot}%{_datadir}/sailfish-weather/backends/
install -p -m 644 backends/AEMETTranslations.js %{buildroot}%{_datadir}/sailfish-weather/backends/
install -p -m 644 backends/AEMETUtils.js %{buildroot}%{_datadir}/sailfish-weather/backends/

# Install the icons
mkdir -p %{buildroot}%{_datadir}/themes/sailfish-default/silica/icons-monochrome
install -p -m 644 icons/graphic-aemet-large.png %{buildroot}%{_datadir}/themes/sailfish-default/silica/icons-monochrome/
install -p -m 644 icons/graphic-aemet-small.png %{buildroot}%{_datadir}/themes/sailfish-default/silica/icons-monochrome/

%files
%defattr(-,root,root,-)
%license LICENSE
%doc README.md
%{_datadir}/sailfish-weather/backends/AEMETBackend.qml
%{_datadir}/sailfish-weather/backends/AEMETTranslations.js
%{_datadir}/sailfish-weather/backends/AEMETUtils.js
%{_datadir}/themes/sailfish-default/silica/icons-monochrome/graphic-aemet-large.png
%{_datadir}/themes/sailfish-default/silica/icons-monochrome/graphic-aemet-small.png
