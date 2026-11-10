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
cp_a = 1005; % [J/(kg K)], value implied by the ME424 Part 4 slide 19 example

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
hf.H2O = -241.827e3; % vapour (ME424 Part 5 slide 15)
hf.CO2 = -393.522e3; % (ME424 Part 5 slide 15)

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
h2.LHV = -hf.H2O/MW.H2; % [J/kg] = 119.95 MJ/kg, implied by the slide 15 data
h2.hf = hf.H2; % [J/mol] (element, = 0)
h2.rho_liq = 70.828; % [kg/m^3], NIST WebBook, parahydrogen, saturated liquid at 0.10132 MPa
h2.h_fg = (446.07 - 0)*1e3; % [J/kg], NIST: h_vapour - h_liquid at 0.10132 MPa

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
% Method: ME424 Part 4 (jets) and Part 5 (combustion) slides.

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

% 3. ENGINE SIZING (provisional)
% Sized at the published max climb thrust (35,000 ft, M0.8, ISA), equal thrust for both fuels.
% Provisional: the hydrogen aircraft's required thrust changes once the tank mass is included.

F_req = F_climb_inst; % required thrust per engine [N]
mc = zeros(1,2);
m_tot = zeros(1,2);
m_fuel = zeros(1,2);
for k = 1:2
  mc(k) = F_req/S.F_sp(k,iopt); % core airflow [kg/s]
  m_tot(k) = (1 + B)*mc(k); % total airflow [kg/s]
  m_fuel(k) = S.f(k,iopt)*mc(k); % fuel flow per engine [kg/s]
end
% Fan diameter: at the same fan face conditions, airflow scales with fan area (D^2).
% The kerosene result is taken to correspond to the real 1.549 m fan.
D_fan = D_fan_base*sqrt(m_tot/m_tot(1)); % [m]

fprintf('\nSizing at F = %.2f kN per engine (provisional)\n', F_req/1e3);
for k = 1:2
  fprintf('%s: core airflow %.2f kg/s, total airflow %.2f kg/s, fuel flow %.4f kg/s (%.0f kg/h), fan diameter %.3f m\n', ...
          fuels{k}.name, mc(k), m_tot(k), m_fuel(k), m_fuel(k)*3600, D_fan(k));
end

% 4. LH2 TANK DESIGN
% Single-wall Al 2219 tank with polyurethane foam insulation, using the full fuselage
% diameter (floor and aft cargo hold removed in the tank bay), replacing the rear seat rows.
% Shape: cylinder with hemispherical ends.

% 4.1 Inputs
D_avail = 139.2*0.0254; % available diameter = cabin interior trim width [m] (Boeing D6-58325-7, 2.5.2)
seat_pitch = 30*0.0254; % pitch of the 184-seat layout [m] (Boeing 2.4.4)
seats_abreast = 6; % [-] (Boeing 2.5.2)
ullage = 0.03; % gas volume fraction [-] (Winnefeld et al. 2018)
p_vent = 1.448e5; % venting pressure [Pa] (Winnefeld et al. 2018)
sig_allow = 172.4e6; % allowable stress, Al 2219 [Pa] (Winnefeld et al. 2018)
rho_wall = 2825; % Al 2219 density [kg/m^3] (Winnefeld et al. 2018)
SF = 1.5; % safety factor, FAR 25.303 [-] (Bagarello et al. 2026)
k_ins = 0.0163; % polyurethane foam conductivity [W/(m K)] (Bagarello et al. 2026)
rho_ins = 96; % polyurethane foam density [kg/m^3] (Bagarello et al. 2026)
T_fus = 283; % fuselage air temperature around the tank [K] (Bagarello et al. 2026)
h_fus = 10; % convection coefficient, outer surface [W/(m^2 K)] (Bagarello et al. 2026)
T_LH2 = 20.271; % LH2 saturation temperature at 0.10132 MPa [K] (NIST)
t_ground = 2*3600; % ground hold with venting [s] (Rompokos et al. 2021)
BOR_limit = 2.5; % allowable boil-off [% of stored mass per day] (Bagarello et al. 2026)
t_ins_range = 0.010:0.001:0.300; % insulation thickness sweep [m]

% 4.2 Fixed quantities
V_tank = m_H2_req/((1 - ullage)*h2.rho_liq); % internal tank volume [m^3]
r_o = D_avail/2; % outer radius of insulation [m]
dp_wall = p_vent - p0; % worst case: depressurised fuselage at cruise [Pa]

% 4.3 Sweep insulation thickness
nT = numel(t_ins_range);
for i = 1:nT
  t_ins = t_ins_range(i);

  % Geometry and wall (hoop stress, thin wall)
  r_1 = r_o - t_ins; % outer radius of wall = inner radius of foam [m]
  t_wall = SF*dp_wall*r_1/sig_allow; % wall thickness [m]
  r_i = r_1 - t_wall; % inner radius [m]
  D_i = 2*r_i; % inner diameter [m]
  L_cyl = (V_tank - pi*D_i^3/6)/(pi*D_i^2/4); % cylinder length [m]

  % Heat leak: foam conduction + outer convection in series; cylinder and end caps in parallel.
  % Inner wall taken at LH2 temperature (inner film and aluminium wall resistance neglected).
  R_cyl = log(r_o/r_1)/(2*pi*k_ins*L_cyl) + 1/(h_fus*2*pi*r_o*L_cyl); % [K/W]
  R_sph = (1/r_1 - 1/r_o)/(4*pi*k_ins) + 1/(h_fus*4*pi*r_o^2); % [K/W]
  Q = (T_fus - T_LH2)*(1/R_cyl + 1/R_sph); % heat leak [W]
  m_bo = Q/h2.h_fg; % boil-off rate [kg/s]

  % Masses
  m_ins = rho_ins*(pi*(r_o^2 - r_1^2)*L_cyl + 4/3*pi*(r_o^3 - r_1^3)); % [kg]
  m_wall = rho_wall*(pi*(r_1^2 - r_i^2)*L_cyl + 4/3*pi*(r_1^3 - r_i^3)); % [kg]

  % Cabin length used and seats lost
  L_out = L_cyl + 2*r_o; % overall tank length [m]
  rows_lost = ceil(L_out/seat_pitch); % [-]

  % Store
  TK.t_wall(i) = t_wall;
  TK.D_i(i) = D_i;
  TK.L_cyl(i) = L_cyl;
  TK.L_out(i) = L_out;
  TK.Q(i) = Q;
  TK.m_bo(i) = m_bo;
  TK.BOR(i) = m_bo*86400/m_H2_req*100; % [% per day]
  TK.m_ins(i) = m_ins;
  TK.m_wall(i) = m_wall;
  TK.m_tank(i) = m_ins + m_wall;
  TK.seats_lost(i) = rows_lost*seats_abreast;
end

% 4.4 Design point: minimum of tank mass + hydrogen vented during the ground hold.
% In flight, boil-off is fed to the engines, so it is not lost (checked below).
TK.penalty = TK.m_tank + TK.m_bo*t_ground; % [kg]
[~, it] = min(TK.penalty);
if it == 1 || it == nT
  warning('Tank optimum is at the end of t_ins_range: widen the range.');
end
t_ins_design = t_ins_range(it);
eta_grav = m_H2_req/(m_H2_req + TK.m_tank(it)); % gravimetric efficiency [-]

fprintf('\nLH2 tank (design insulation thickness = %.3f m)\n', t_ins_design);
fprintf('Tank volume %.1f m^3 (liquid %.1f m^3 + %.0f%% ullage)\n', V_tank, m_H2_req/h2.rho_liq, ullage*100);
fprintf('Wall thickness %.2f mm, inner diameter %.3f m, cylinder length %.2f m, overall length %.2f m\n', ...
        TK.t_wall(it)*1e3, TK.D_i(it), TK.L_cyl(it), TK.L_out(it));
fprintf('Seats lost %d, seats remaining %d (of %d)\n', TK.seats_lost(it), ac.seats - TK.seats_lost(it), ac.seats);
fprintf('Heat leak %.0f W, boil-off %.1f kg/h = %.1f%% per day\n', TK.Q(it), TK.m_bo(it)*3600, TK.BOR(it));
fprintf('Mass: insulation %.0f kg + wall %.0f kg = %.0f kg, gravimetric efficiency %.1f%%\n', ...
        TK.m_ins(it), TK.m_wall(it), TK.m_tank(it), eta_grav*100);
fprintf('Hydrogen vented in %.0f h ground hold: %.0f kg\n', t_ground/3600, TK.m_bo(it)*t_ground);
fprintf('In flight: boil-off %.0f kg/h vs engine demand %.0f kg/h (%d engines, provisional)\n', ...
        TK.m_bo(it)*3600, n_eng*m_fuel(2)*3600, n_eng);
if any(TK.BOR <= BOR_limit)
  fprintf('%.1f%% per day limit met from t_ins = %.3f m\n', BOR_limit, t_ins_range(find(TK.BOR <= BOR_limit, 1)));
else
  fprintf('No thickness in the sweep meets the %.1f%% per day limit (best %.1f%% per day at %.2f m)\n', ...
          BOR_limit, min(TK.BOR), t_ins_range(end));
end

% Sensitivity of the optimum to the ground hold assumption
for th = [1 2 4]
  [~, ii] = min(TK.m_tank + TK.m_bo*th*3600);
  fprintf('Ground hold %d h: optimum t_ins = %.3f m\n', th, t_ins_range(ii));
end

% 4.5 Plot: insulation thickness sweep
figure('Name', 'Insulation thickness sweep');
subplot(3,1,1);
plot(t_ins_range*100, TK.m_tank, 'LineWidth', 1.5);
hold on;
plot(t_ins_range*100, TK.penalty, 'LineWidth', 1.5);
plot(t_ins_design*100, TK.penalty(it), 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
grid on;
ylabel('Mass [kg]');
legend('Tank mass', 'Tank mass + ground-hold loss', 'Design point', 'Location', 'north');
subplot(3,1,2);
plot(t_ins_range*100, TK.m_bo*3600, 'LineWidth', 1.5);
hold on;
plot(t_ins_design*100, TK.m_bo(it)*3600, 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
grid on;
ylabel('Boil-off [kg/h]');
subplot(3,1,3);
stairs(t_ins_range*100, TK.seats_lost, 'LineWidth', 1.5);
hold on;
plot(t_ins_design*100, TK.seats_lost(it), 'o', 'MarkerSize', 7, 'LineWidth', 1.5);
grid on;
xlabel('Insulation thickness [cm]');
ylabel('Seats lost [-]');
