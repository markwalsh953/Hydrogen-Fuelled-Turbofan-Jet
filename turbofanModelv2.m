% ME424 Hydrogen turbofan project: cruise design-point cycle model
% Station numbering (ME424 Part 4 slides): 1 flight, 2 fan face, f fan exit, 3 core compressor exit, 4 combustor exit, 5 turbine exit, 6 core nozzle exit, b bypass nozzle exit. Leading 0 = total property. In section 1, T0, p0, V0 are the ambient static values.

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
% This is a search range, not a claimed value. Must contain the optimum (about 2.5).
FPR_range = 1.3:0.02:3.2; % [-]

% 1.5 Component losses: PLACEHOLDERS
pi_intake = 1.00; % intake stagnation pressure recovery [-]
pi_comb = 1.00; % combustor pressure ratio p04/p03 [-]
eta_comb = 1.00; % combustion efficiency [-] (brief: complete combustion can be assumed, so 1.00 is OK)
eta_mech = 1.00; % mechanical (shaft) efficiency [-]
eta_noz = 1.00; % nozzle efficiency [-]

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
hf.O2 = 0;
hf.N2 = 0;
hf.H2 = 0;
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
h2.rho_liq = NaN; % [kg/m^3] <-- FILL IN
h2.h_fg = NaN; % [J/kg] <-- FILL IN (h_vap - h_liq)

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
energy_fraction = 0.80; % given in brief
E_fuel_ker = ac.fuel_mass*ker.LHV; % [J]
m_H2_req = energy_fraction*E_fuel_ker/h2.LHV; % required H2 mass [kg]

% Print key inputs
fprintf('Design point: %.0f ft (%.0f m), M = %.2f, ISA\n', h_ft, h, M0);
fprintf('T0 = %.2f K, p0 = %.0f Pa, V0 = %.1f m/s\n', T0, p0, V0);
fprintf('Kerosene: MW = %.4f kg/mol, hf = %.1f kJ/mol, rho = %.0f kg/m^3\n', ker.MW, ker.hf/1e3, ker.rho);
fprintf('Required H2 mass for 80%% energy: %.0f kg\n', m_H2_req);

% 2. CYCLE CALCULATION
% Per 1 kg/s of core air, for each fuel and each fan pressure ratio.

% Ambient static values in lecture notation (station 1)
T1 = T0; % [K]
p1 = p0; % [Pa]
V1 = V0; % [m/s]
M1 = M0; % [-]

% 2.1 Combustion property data (ME424 Part 5 slides)
Tref = 298.15; % reference state, 25 C [K] (slide 13)
% Constant specific heats [J/(kg K)] (slides 20 and 23)
% NB slide 20 writes the N2 term as 14.55*dT; 28 x 1.039 = 29.1, as on slide 23
cps.CO2 = 846;
cps.H2O = 1872.3;
cps.N2 = 1039;
cps.O2 = 918;

% 2.2 Flight condition and intake (Part 4 slide 13, ideal intake as in slide 19)
T01 = T1*(1 + (gamma_a-1)/2*M1^2); % total temperature [K]
p01 = p1*(1 + (gamma_a-1)/2*M1^2)^(gamma_a/(gamma_a-1)); % total pressure [Pa]
T02 = T01; % [K]
p02 = pi_intake*p01; % [Pa]

nc = (gamma_a-1)/(gamma_a*eta_p); % polytropic compression exponent [-] (slide 16)
crit_a = ((gamma_a+1)/2)^(gamma_a/(gamma_a-1)); % critical pressure ratio, air nozzle [-]

fuels = {ker, h2};
nF = numel(FPR_range);

for k = 1:2
  fu = fuels{k};
  st = fu.a + fu.b/4; % stoichiometric O2 [mol per mol fuel]

  for j = 1:nF
    FPR = FPR_range(j);

    % 2.3 Fan (2 -> f), polytropic (slide 16)
    p0f = FPR*p02; % [Pa]
    T0f = T02*FPR^nc; % [K]

    % 2.4 Core compressor (f -> 3)
    p03 = OPR*p02; % [Pa]
    T03 = T0f*(p03/p0f)^nc; % [K]

    % 2.5 Combustor (3 -> 4), Part 5 slides 19-23
    % CaHb + lam*st*(O2 + 3.76 N2) -> a CO2 + (b/2) H2O + (lam-1)*st O2 + 3.76*lam*st N2
    % H_reactants = H_products: fuel at 25 C, air at T03, products at T04
    dT3 = T03 - Tref; % [K]
    dT4 = T04 - Tref; % [K]
    A = st*(MW.O2*cps.O2 + N2_O2*MW.N2*cps.N2); % air molar heat capacity per unit lam [J/(mol K)]
    P = fu.a*(hf.CO2 + MW.CO2*cps.CO2*dT4) + (fu.b/2)*(hf.H2O + MW.H2O*cps.H2O*dT4); % CO2 + H2O enthalpy [J/mol fuel]
    lam = (fu.hf - P + st*MW.O2*cps.O2*dT4)/(A*(dT4 - dT3)); % air-fuel equivalence ratio [-]

    % Products [mol per mol fuel]
    n_CO2 = fu.a;
    n_H2O = fu.b/2;
    n_O2 = (lam - 1)*st;
    n_N2 = N2_O2*lam*st;

    m_air = lam*st*(MW.O2 + N2_O2*MW.N2); % air [kg per mol fuel]
    f = fu.MW/m_air; % fuel-air ratio [-]

    % Mass-weighted product properties (brief)
    m_CO2 = n_CO2*MW.CO2; % [kg per mol fuel]
    m_H2O = n_H2O*MW.H2O;
    m_O2 = n_O2*MW.O2;
    m_N2 = n_N2*MW.N2;
    m_tot = m_CO2 + m_H2O + m_O2 + m_N2;
    cp_g = (m_CO2*cps.CO2 + m_H2O*cps.H2O + m_O2*cps.O2 + m_N2*cps.N2)/m_tot; % [J/(kg K)]
    MW_g = m_tot/(n_CO2 + n_H2O + n_O2 + n_N2); % [kg/mol]
    R_g = R_u/MW_g; % [J/(kg K)]
    gam_g = cp_g/(cp_g - R_g); % [-]

    p04 = pi_comb*p03; % [Pa]

    % 2.6 Turbine (4 -> 5): turbine work = fan + compressor work (slide 17)
    w_c = (1 + B)*cp_a*(T0f - T02) + cp_a*(T03 - T0f); % [J per kg core air]
    T05 = T04 - w_c/(eta_mech*(1 + f)*cp_g); % [K]
    p05 = p04*(T05/T04)^(gam_g/(eta_p*(gam_g - 1))); % [Pa] (slide 16, turbine)

    % 2.7 Core nozzle (5 -> 6), convergent, choking check (slide 17)
    crit_g = ((gam_g + 1)/2)^(gam_g/(gam_g - 1)); % critical pressure ratio [-]
    if p05/p1 > crit_g % choked, M6 = 1
      T6 = 2*T05/(gam_g + 1); % [K]
      p6 = p05/crit_g; % [Pa]
      V6 = sqrt(gam_g*R_g*T6); % [m/s]
      choke6 = 1;
    else % fully expanded, p6 = p1
      p6 = p1;
      T6 = T05*(p1/p05)^((gam_g - 1)/gam_g);
      V6 = sqrt(2*cp_g*(T05 - T6));
      choke6 = 0;
    end
    rho6 = p6/(R_g*T6); % [kg/m^3]

    % 2.8 Bypass nozzle (f -> b), air
    if p0f/p1 > crit_a % choked, Mb = 1
      Tb = 2*T0f/(gamma_a + 1); % [K]
      pb = p0f/crit_a; % [Pa]
      Vb = sqrt(gamma_a*R_a*Tb); % [m/s]
      chokeb = 1;
    else % fully expanded, pb = p1
      pb = p1;
      Tb = T0f*(p1/p0f)^((gamma_a - 1)/gamma_a);
      Vb = sqrt(2*cp_a*(T0f - Tb));
      chokeb = 0;
    end
    rhob = pb/(R_a*Tb); % [kg/m^3]

    % 2.9 Thrust (slide 18) and TSFC, per kg/s core air
    % F = m(u_exit - u1) + (p_exit - p1)*A_exit, with A_exit = m/(rho*V)
    F_core = (1 + f)*(V6 + (p6 - p1)/(rho6*V6)) - V1; % [N]
    F_byp = B*(Vb - V1 + (pb - p1)/(rhob*Vb)); % [N]
    F_sp = F_core + F_byp; % specific thrust [N per kg/s core air]

    % Store results: row k = fuel, column j = fan pressure ratio
    S.T0f(k,j) = T0f;
    S.p0f(k,j) = p0f;
    S.T03(k,j) = T03;
    S.p03(k,j) = p03;
    S.lam(k,j) = lam;
    S.f(k,j) = f;
    S.y(k,j,:) = [m_CO2 m_H2O m_O2 m_N2]/m_tot; % mass fractions CO2, H2O, O2, N2
    S.cp_g(k,j) = cp_g;
    S.R_g(k,j) = R_g;
    S.gam_g(k,j) = gam_g;
    S.w_c(k,j) = w_c;
    S.T05(k,j) = T05;
    S.p05(k,j) = p05;
    S.T6(k,j) = T6;
    S.p6(k,j) = p6;
    S.V6(k,j) = V6;
    S.choke6(k,j) = choke6;
    S.Tb(k,j) = Tb;
    S.pb(k,j) = pb;
    S.Vb(k,j) = Vb;
    S.chokeb(k,j) = chokeb;
    S.F_core(k,j) = F_core;
    S.F_byp(k,j) = F_byp;
    S.F_sp(k,j) = F_sp;
    S.TSFC(k,j) = f/F_sp; % [kg/(N s)]
    S.ESFC(k,j) = f/F_sp*fu.LHV; % energy per unit thrust [W/N]
  end
end

% 2.10 Design point: kerosene TSFC optimum. Same FPR used for hydrogen (brief: same pressure ratios)
[~, iopt] = min(S.TSFC(1,:));
FPR_design = FPR_range(iopt); % [-]
[~, iopt_h2] = min(S.TSFC(2,:));
if iopt == 1 || iopt == nF
  warning('Kerosene TSFC optimum is at the end of FPR_range: widen the range.');
end

% Print design-point results
j = iopt;
fprintf('\nDesign point FPR = %.2f (hydrogen optimum would be %.2f)\n', FPR_design, FPR_range(iopt_h2));
fprintf('Station 1,2: T0 = %.1f K, p0 = %.2f kPa\n', T01, p01/1e3);
fprintf('Station f: T0 = %.1f K, p0 = %.2f kPa\n', S.T0f(1,j), S.p0f(1,j)/1e3);
fprintf('Station 3: T0 = %.1f K, p0 = %.2f kPa\n', S.T03(1,j), S.p03(1,j)/1e3);
fprintf('Station 4: T0 = %.1f K, p0 = %.2f kPa\n', T04, pi_comb*S.p03(1,j)/1e3);
for k = 1:2
  fprintf('\n%s\n', fuels{k}.name);
  fprintf('lambda = %.3f, f = %.5f\n', S.lam(k,j), S.f(k,j));
  fprintf('Mass fractions: CO2 %.4f, H2O %.4f, O2 %.4f, N2 %.4f\n', S.y(k,j,1), S.y(k,j,2), S.y(k,j,3), S.y(k,j,4));
  fprintf('cp_g = %.1f J/(kg K), R_g = %.1f J/(kg K), gamma_g = %.4f\n', S.cp_g(k,j), S.R_g(k,j), S.gam_g(k,j));
  fprintf('Fan + compressor work = %.0f J/kg core air\n', S.w_c(k,j));
  fprintf('Station 5: T0 = %.1f K, p0 = %.2f kPa\n', S.T05(k,j), S.p05(k,j)/1e3);
  fprintf('Core nozzle: choked = %d, T6 = %.1f K, p6 = %.2f kPa, V6 = %.1f m/s\n', S.choke6(k,j), S.T6(k,j), S.p6(k,j)/1e3, S.V6(k,j));
  fprintf('Bypass nozzle: choked = %d, Tb = %.1f K, pb = %.2f kPa, Vb = %.1f m/s\n', S.chokeb(k,j), S.Tb(k,j), S.pb(k,j)/1e3, S.Vb(k,j));
  fprintf('Specific thrust: core %.1f + bypass %.1f = %.1f N per kg/s core air\n', S.F_core(k,j), S.F_byp(k,j), S.F_sp(k,j));
  fprintf('TSFC = %.2f g/(kN s) = %.3f lb/(lbf h), ESFC = %.1f W/N\n', S.TSFC(k,j)*1e6, S.TSFC(k,j)*3600*g, S.ESFC(k,j));
end

% 2.11 Plot: TSFC against fan pressure ratio
figure('Name', 'Fan pressure ratio sweep');
for k = 1:2
  subplot(2,1,k);
  plot(FPR_range, S.TSFC(k,:)*1e6, 'LineWidth', 1.5);
  hold on;
  plot(FPR_design, S.TSFC(k,iopt)*1e6, 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
  grid on;
  xlabel('Fan pressure ratio [-]');
  ylabel('TSFC [g/(kN s)]');
  title(fuels{k}.name);
  legend('Sweep', 'Design point', 'Location', 'north');
end
