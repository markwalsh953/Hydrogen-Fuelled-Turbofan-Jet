% ME424 Hydrogen turbofan project: cruise design-point cycle model
% Station numbering: 0 freestream, 2 fan face, 13 fan exit, 3 core compressor exit, 4 combustor exit, 5 turbine exit, 9 core nozzle exit, 19 bypass nozzle exit.

clear;
clc;

% 1. INPUTS

% 1.1 Flight condition (design point)
h_ft = 35000; % altitude [ft]
h = h_ft * 0.3048; % altitude [m]
M0 = 0.8; % flight Mach number [-]

% 1.2 Standard atmosphere (troposphere, h < 11 km)
T_SL = 288.15; % sea-level temperature [K]
p_SL = 101325; % sea-level pressure [Pa]
L = 0.0065; % ISA lapse rate [K/m]
g = 9.80665; % gravitational acceleration [m/s^2]
M_air_mol = 0.0289644; % molar mass of dry air [kg/mol]
R_u  = 8.314462618; % universal gas constant [J/(mol K)]

T0 = T_SL - L*h; % ambient temperature [K]
p0 = p_SL * (T0/T_SL)^(g*M_air_mol/(R_u*L)); % ambient pressure [Pa]

% 1.3 Air properties (cold section)
gamma_a = 1.4; % ratio of specific heats, air [-]
R_a = 287; % specific gas constant, air [J/(kg K)]
cp_a = gamma_a*R_a/(gamma_a - 1); % = 1004.5 J/(kg K)

a0 = sqrt(gamma_a*R_a*T0); % speed of sound [m/s]
V0 = M0*a0; % flight speed [m/s]

% 1.4 Baseline engine: CFM56-7B27
B = 5.1; % bypass ratio [-]
OPR = 32.7; % overall pressure ratio at max climb [-]
D_fan_base = 61*0.0254; % baseline fan diameter [m] (1.549 m)
F_climb_inst = 5960*4.44822; % max climb thrust per engine
n_eng = 2; % engines per aircraft [-]

% Source: project brief defaults
T04 = 1600 + 273.15; % turbine inlet temperature [K]
eta_p = 0.85; % polytropic (small-stage) efficiency, applied to fan, compressor and turbines [-]

% Fan pressure ratio: NOT published. Swept to find the best TSFC.
% This is a search range, not a claimed value.
FPR_range = 1.3:0.02:2.2; % [-]

% 1.5 Component losses: PLACEHOLDERS
% Set to ideal so the script runs. REPLACE with values from your lecture
% notes or Saravanamuttoo et al., Gas Turbine Theory, and cite them.
pi_intake = 1.00; % intake stagnation pressure recovery [-]
pi_comb   = 1.00; % combustor pressure ratio p04/p03 [-]
eta_comb  = 1.00; % combustion efficiency [-] (brief: complete combustion can be assumed, so 1.00 is OK)
eta_mech  = 1.00; % mechanical (shaft) efficiency [-]
eta_noz   = 1.00; % nozzle efficiency [-]

% 1.6 Combustion data
% Air modelled as O2 + 3.76 N2
N2_O2 = 3.76; % mol N2 per mol O2 in air [-]

% Molar masses [kg/mol]
MW.O2 = 0.031999;
MW.N2 = 0.028013;
MW.H2O = 0.018015;
MW.CO2 = 0.044010;
MW.H2 = 0.002016;
MW.C = 0.012011;
MW.H = 0.001008;

% Standard enthalpies of formation at 298.15 K [J/mol]
hf.O2  = 0;
hf.N2  = 0;
hf.H2  = 0;
hf.H2O = -241.8e3; % vapour
hf.CO2 = -393.5e3;

% 1.7 Fuels
% Kerosene (Jet A-1), C12H23
ker.name = 'Kerosene (Jet A-1)';
ker.a = 12; % carbon atoms
ker.b = 23; % hydrogen atoms
ker.MW = ker.a*MW.C + ker.b*MW.H; % [kg/mol]
ker.LHV = 42.8e6; % [J/kg], ASTM D1655 / DEF STAN 91-091 minimum
ker.rho = 20897/26.024; % [kg/m^3], from Boeing usable fuel mass/volume
ker.hf = ker.LHV*ker.MW + ker.a*hf.CO2 + (ker.b/2)*hf.H2O; % [J/mol]

% Hydrogen, H2
h2.name = 'Hydrogen';
h2.a = 0;
h2.b = 2;
h2.MW = MW.H2;
h2.LHV = 120e6; % [J/kg]
h2.hf = hf.H2; % [J/mol] (element, = 0)
h2.rho_liq = NaN; % [kg/m^3]  <-- FILL IN
h2.h_fg    = NaN; % [J/kg]    <-- FILL IN (h_vap - h_liq)

% 1.8 Baseline aircraft: Boeing 737-800, heaviest variant
ac.MTOW = 79015; % max design takeoff weight [kg]
ac.MLW = 66360; % max design landing weight [kg]
ac.MZFW = 62731; % max design zero fuel weight [kg]
ac.OEW = 41412; % operating empty weight [kg]
ac.payload_max = 21318; % max structural payload [kg]
ac.seats  = 184; % all-economy [-]
ac.fuel_mass = 20897; % usable fuel [kg]
ac.fuel_vol  = 26.024; % usable fuel [m^3]
ac.fuselage_length = (129 + 6/12)*0.3048; % overall length [m]

% Hydrogen design constraint (project brief): fuel energy = 80% of kerosene
energy_fraction = 0.80; # given in brief
E_fuel_ker = ac.fuel_mass*ker.LHV; % [J]
m_H2_req = energy_fraction*E_fuel_ker/h2.LHV; % required H2 mass [kg]

% Print key inputs
fprintf('Design point: %.0f ft (%.0f m), M = %.2f, ISA\n', h_ft, h, M0);
fprintf('T0 = %.2f K, p0 = %.0f Pa, V0 = %.1f m/s\n', T0, p0, V0);
fprintf('Kerosene: MW = %.4f kg/mol, hf = %.1f kJ/mol, rho = %.0f kg/m^3\n', ker.MW, ker.hf/1e3, ker.rho);
fprintf('Required H2 mass for 80%% energy: %.0f kg\n', m_H2_req);
