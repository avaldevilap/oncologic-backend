CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE SCHEMA auth;
CREATE OR REPLACE FUNCTION public.set_current_timestamp_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  _new record;
begin
  _new := new;
  _new. "updated_at" = now();
  return _new;
end;
$$;
CREATE TABLE auth.account_providers (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    account_id uuid NOT NULL,
    auth_provider text NOT NULL,
    auth_provider_unique_id text NOT NULL
);
CREATE TABLE auth.account_roles (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    account_id uuid NOT NULL,
    role text NOT NULL
);
CREATE TABLE auth.accounts (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id uuid NOT NULL,
    active boolean DEFAULT false NOT NULL,
    email public.citext,
    new_email public.citext,
    password_hash text,
    default_role text DEFAULT 'user'::text NOT NULL,
    is_anonymous boolean DEFAULT false NOT NULL,
    custom_register_data jsonb,
    otp_secret text,
    mfa_enabled boolean DEFAULT false NOT NULL,
    ticket uuid DEFAULT public.gen_random_uuid() NOT NULL,
    ticket_expires_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT proper_email CHECK ((email OPERATOR(public.~*) '^[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'::public.citext)),
    CONSTRAINT proper_new_email CHECK ((new_email OPERATOR(public.~*) '^[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'::public.citext))
);
CREATE TABLE auth.providers (
    provider text NOT NULL
);
CREATE TABLE auth.refresh_tokens (
    refresh_token uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    account_id uuid NOT NULL
);
CREATE TABLE auth.roles (
    role text NOT NULL
);
CREATE TABLE public.users (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    display_name text,
    avatar_url text
);
ALTER TABLE ONLY auth.account_providers
    ADD CONSTRAINT account_providers_account_id_auth_provider_key UNIQUE (account_id, auth_provider);
ALTER TABLE ONLY auth.account_providers
    ADD CONSTRAINT account_providers_auth_provider_auth_provider_unique_id_key UNIQUE (auth_provider, auth_provider_unique_id);
ALTER TABLE ONLY auth.account_providers
    ADD CONSTRAINT account_providers_pkey PRIMARY KEY (id);
ALTER TABLE ONLY auth.account_roles
    ADD CONSTRAINT account_roles_pkey PRIMARY KEY (id);
ALTER TABLE ONLY auth.accounts
    ADD CONSTRAINT accounts_email_key UNIQUE (email);
ALTER TABLE ONLY auth.accounts
    ADD CONSTRAINT accounts_new_email_key UNIQUE (new_email);
ALTER TABLE ONLY auth.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);
ALTER TABLE ONLY auth.accounts
    ADD CONSTRAINT accounts_user_id_key UNIQUE (user_id);
ALTER TABLE ONLY auth.providers
    ADD CONSTRAINT providers_pkey PRIMARY KEY (provider);
ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (refresh_token);
ALTER TABLE ONLY auth.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (role);
ALTER TABLE ONLY auth.account_roles
    ADD CONSTRAINT user_roles_account_id_role_key UNIQUE (account_id, role);
ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
CREATE TRIGGER set_auth_account_providers_updated_at BEFORE UPDATE ON auth.account_providers FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();
CREATE TRIGGER set_auth_accounts_updated_at BEFORE UPDATE ON auth.accounts FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();
CREATE TRIGGER set_public_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();
ALTER TABLE ONLY auth.account_providers
    ADD CONSTRAINT account_providers_account_id_fkey FOREIGN KEY (account_id) REFERENCES auth.accounts(id) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE ONLY auth.account_providers
    ADD CONSTRAINT account_providers_auth_provider_fkey FOREIGN KEY (auth_provider) REFERENCES auth.providers(provider) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE ONLY auth.account_roles
    ADD CONSTRAINT account_roles_account_id_fkey FOREIGN KEY (account_id) REFERENCES auth.accounts(id) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE ONLY auth.account_roles
    ADD CONSTRAINT account_roles_role_fkey FOREIGN KEY (role) REFERENCES auth.roles(role) ON UPDATE CASCADE ON DELETE RESTRICT;
ALTER TABLE ONLY auth.accounts
    ADD CONSTRAINT accounts_default_role_fkey FOREIGN KEY (default_role) REFERENCES auth.roles(role) ON UPDATE CASCADE ON DELETE RESTRICT;
ALTER TABLE ONLY auth.accounts
    ADD CONSTRAINT accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_account_id_fkey FOREIGN KEY (account_id) REFERENCES auth.accounts(id) ON UPDATE CASCADE ON DELETE CASCADE;

INSERT INTO auth.roles (role)
    VALUES ('user'), ('anonymous');

INSERT INTO auth.providers (provider)
    VALUES ('github'), ('facebook'), ('twitter'), ('google'), ('apple'),  ('linkedin'), ('windowslive');

CREATE TABLE public.patients (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    identifier text,
    active boolean DEFAULT true NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    phone_number text,
    deceased_at timestamp with time zone,
    address text NOT NULL,
    marital_status text DEFAULT 'unknown'::text NOT NULL,
    multiple_birth integer,
    gender text NOT NULL,
    municipality_id integer,
    birthdate date,
    CONSTRAINT identifier_length CHECK ((length(identifier) = 11))
);
CREATE FUNCTION public.calc_age(patient_row public.patients) RETURNS double precision
    LANGUAGE sql STABLE
    AS $$
  SELECT date_part('year', age(patient_row.birthdate))
$$;
CREATE FUNCTION public.patients_full_name(patient_row public.patients) RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT patient_row.first_name || ' ' || patient_row.last_name
$$;
CREATE TABLE public.practitioners (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    identifier character varying,
    active boolean DEFAULT true NOT NULL,
    first_name name NOT NULL,
    last_name name NOT NULL,
    phone_number text,
    address text,
    gender text,
    birthdate date,
    qualification_id integer
);
COMMENT ON TABLE public.practitioners IS 'A person who is directly or indirectly involved in the provisioning of healthcare';
CREATE FUNCTION public.practitioner_full_name(practitioner_row public.practitioners) RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT practitioner_row.first_name || ' ' || practitioner_row.last_name
$$;
CREATE TABLE public.biopsies (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    patient_id uuid,
    number text NOT NULL,
    sample text NOT NULL,
    entry_date date,
    macroscopic_date date,
    microscopic_date date,
    service text,
    clinical_diagnosis text,
    pathological_diagnosis text,
    macroscopic_description text,
    microscopic_description text,
    anatomopathological_report text
);
CREATE TABLE public.biopsy_practitioner (
    biopsy_id uuid NOT NULL,
    practitioner_id uuid NOT NULL
);
CREATE TABLE public.cytologies (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    patient_id uuid NOT NULL,
    number text,
    sample text NOT NULL,
    entry_date date NOT NULL,
    date_of_diagnosis date,
    service text NOT NULL,
    clinical_diagnosis text,
    cytological_diagnosis text
);
CREATE TABLE public.cytology_practitioner (
    cytology_id uuid NOT NULL,
    practitioner_id uuid NOT NULL
);
CREATE TABLE public.municipalities (
    code integer NOT NULL,
    name character varying NOT NULL,
    province_id integer NOT NULL
);
CREATE TABLE public.necropsies (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    patient_id uuid NOT NULL,
    number text NOT NULL,
    date_of_admission date NOT NULL,
    date_of_discharge date,
    evisceration_date date,
    dissection_date date,
    service text NOT NULL
);
CREATE TABLE public.necropsy_practitioner (
    necropsy_id uuid NOT NULL,
    practitioner_id uuid NOT NULL
);
CREATE TABLE public.provinces (
    code integer NOT NULL,
    name character varying NOT NULL
);
CREATE TABLE public.qualifications (
    id integer NOT NULL,
    identifier character varying,
    code text,
    period daterange
);
CREATE SEQUENCE public.qualifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.qualifications_id_seq OWNED BY public.qualifications.id;
ALTER TABLE ONLY public.qualifications ALTER COLUMN id SET DEFAULT nextval('public.qualifications_id_seq'::regclass);
ALTER TABLE ONLY public.biopsies
    ADD CONSTRAINT biopsies_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.biopsy_practitioner
    ADD CONSTRAINT biopsy_practitioner_pkey PRIMARY KEY (biopsy_id, practitioner_id);
ALTER TABLE ONLY public.cytologies
    ADD CONSTRAINT cytologies_number_key UNIQUE (number);
ALTER TABLE ONLY public.cytologies
    ADD CONSTRAINT cytologies_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.cytology_practitioner
    ADD CONSTRAINT cytology_practitioner_pkey PRIMARY KEY (cytology_id, practitioner_id);
ALTER TABLE ONLY public.practitioners
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.municipalities
    ADD CONSTRAINT municipalities_pkey PRIMARY KEY (code);
ALTER TABLE ONLY public.necropsies
    ADD CONSTRAINT necropsies_number_key UNIQUE (number);
ALTER TABLE ONLY public.necropsies
    ADD CONSTRAINT necropsies_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.necropsy_practitioner
    ADD CONSTRAINT necropsy_practitioner_pkey PRIMARY KEY (necropsy_id, practitioner_id);
ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_identifier_key UNIQUE (identifier);
ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.practitioners
    ADD CONSTRAINT practitioners_identifier_key UNIQUE (identifier);
ALTER TABLE ONLY public.provinces
    ADD CONSTRAINT provinces_pkey PRIMARY KEY (code);
ALTER TABLE ONLY public.qualifications
    ADD CONSTRAINT qualifications_pkey PRIMARY KEY (id);
CREATE TRIGGER set_public_biopsies_updated_at BEFORE UPDATE ON public.biopsies FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();
COMMENT ON TRIGGER set_public_biopsies_updated_at ON public.biopsies IS 'trigger to set value of column "updated_at" to current timestamp on row update';
CREATE TRIGGER set_public_cytologies_updated_at BEFORE UPDATE ON public.cytologies FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();
COMMENT ON TRIGGER set_public_cytologies_updated_at ON public.cytologies IS 'trigger to set value of column "updated_at" to current timestamp on row update';
CREATE TRIGGER set_public_employees_updated_at BEFORE UPDATE ON public.practitioners FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();
COMMENT ON TRIGGER set_public_employees_updated_at ON public.practitioners IS 'trigger to set value of column "updated_at" to current timestamp on row update';
CREATE TRIGGER set_public_necropsies_updated_at BEFORE UPDATE ON public.necropsies FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();
COMMENT ON TRIGGER set_public_necropsies_updated_at ON public.necropsies IS 'trigger to set value of column "updated_at" to current timestamp on row update';
CREATE TRIGGER set_public_patients_updated_at BEFORE UPDATE ON public.patients FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();
COMMENT ON TRIGGER set_public_patients_updated_at ON public.patients IS 'trigger to set value of column "updated_at" to current timestamp on row update';
ALTER TABLE ONLY public.biopsy_practitioner
    ADD CONSTRAINT biopsy_practitioner_biopsy_id_fkey FOREIGN KEY (biopsy_id) REFERENCES public.biopsies(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE ONLY public.biopsy_practitioner
    ADD CONSTRAINT biopsy_practitioner_practitioner_id_fkey FOREIGN KEY (practitioner_id) REFERENCES public.practitioners(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE ONLY public.cytology_practitioner
    ADD CONSTRAINT cytology_practitioner_cytology_id_fkey FOREIGN KEY (cytology_id) REFERENCES public.cytologies(id) ON UPDATE CASCADE ON DELETE RESTRICT;
ALTER TABLE ONLY public.cytology_practitioner
    ADD CONSTRAINT cytology_practitioner_practitioner_id_fkey FOREIGN KEY (practitioner_id) REFERENCES public.practitioners(id) ON UPDATE CASCADE ON DELETE RESTRICT;
ALTER TABLE ONLY public.municipalities
    ADD CONSTRAINT municipalities_province_id_fkey FOREIGN KEY (province_id) REFERENCES public.provinces(code) ON UPDATE RESTRICT ON DELETE CASCADE;
ALTER TABLE ONLY public.necropsy_practitioner
    ADD CONSTRAINT necropsy_practitioner_necropsy_id_fkey FOREIGN KEY (necropsy_id) REFERENCES public.necropsies(id) ON UPDATE CASCADE ON DELETE RESTRICT;
ALTER TABLE ONLY public.necropsy_practitioner
    ADD CONSTRAINT necropsy_practitioner_practitioner_id_fkey FOREIGN KEY (practitioner_id) REFERENCES public.practitioners(id) ON UPDATE CASCADE ON DELETE RESTRICT;
ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_municipality_id_fkey FOREIGN KEY (municipality_id) REFERENCES public.municipalities(code) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE ONLY public.practitioners
    ADD CONSTRAINT practitioners_qualification_id_fkey FOREIGN KEY (qualification_id) REFERENCES public.qualifications(id) ON UPDATE RESTRICT ON DELETE CASCADE;

INSERT INTO provinces (code, name) VALUES
(21, 'Pinar del Río'),
(22, 'Artemisa'),
(23, 'La Habana'),
(24, 'Mayabeque'),
(25, 'Matanzas'),
(26, 'Villa Clara'),
(27, 'Cienfuegos'),
(28, 'Sancti Spiritus'),
(29, 'Ciego de Ávila'),
(30, 'Camagüey'),
(31, 'Las Tunas'),
(32, 'Holguín'),
(33, 'Granma'),
(34, 'Santiago de Cuba'),
(35, 'Guantánamo'),
(4001, 'Isla de la Juventud');

INSERT INTO municipalities (code, name, province_id) VALUES
(2101, 'Sandino', 21),
(2102, 'Mantua', 21),
(2103, 'Minas de Matahambre', 21),
(2104, 'Viñales', 21),
(2105, 'La Palma', 21),
(2106, 'Los Palacios', 21),
(2107, 'Consolación del Sur', 21),
(2108, 'Pinar del Río', 21),
(2109, 'San Luis', 21),
(2110, 'San Juan y Martínez', 21),
(2111, 'Güane', 21),
(2201, 'Bahía Honda', 22),
(2202, 'Mariel', 22),
(2203, 'Guanajay', 22),
(2204, 'Caimito', 22),
(2205, 'Bauta', 22),
(2206, 'San Antonio de los Baños', 22),
(2207, 'Güira de Melena', 22),
(2208, 'Alquízar', 22),
(2209, 'Artemisa', 22),
(2210, 'Candelaria', 22),
(2211, 'San Cristóbal', 22),
(2301, 'Playa', 23),
(2302, 'Plaza de la Revolución', 23),
(2303, 'Centro Habana', 23),
(2304, 'La Habana Vieja', 23),
(2305, 'Regla', 23),
(2306, 'La Habana del Este', 23),
(2307, 'Guanabacoa', 23),
(2308, 'San Miguel del Padrón', 23),
(2309, 'Diez de Octubre', 23),
(2310, 'Cerro', 23),
(2311, 'Marianao', 23),
(2312, 'La Lisa', 23),
(2313, 'Boyeros', 23),
(2314, 'Arroyo Naranjo', 23),
(2315, 'Cotorro', 23),
(2401, 'Bejucal', 24),
(2402, 'San José de las Lajas', 24),
(2403, 'Jaruco', 24),
(2404, 'Santa Cruz del Norte', 24),
(2405, 'Madruga', 24),
(2406, 'Nueva Paz', 24),
(2407, 'San Nicolás', 24),
(2408, 'Guines', 24),
(2409, 'Melena del Sur', 24),
(2410, 'Batabanó', 24),
(2411, 'Quivicán', 24),
(2501, 'Matanzas', 25),
(2502, 'Cárdenas', 25),
(2503, 'Martí', 25),
(2504, 'Colón', 25),
(2505, 'Perico', 25),
(2506, 'Jovellanos', 25),
(2507, 'Pedro Betancourt', 25),
(2508, 'Limonar', 25),
(2509, 'Unión de Reyes', 25),
(2510, 'Ciénaga de Zapata', 25),
(2511, 'Jagüey Grande', 25),
(2512, 'Calimete', 25),
(2513, 'Los Arabos', 25),
(2601, 'Corralillo', 26),
(2602, 'Quemado de Güines', 26),
(2603, 'Sagua la Grande', 26),
(2604, 'Encrucijada', 26),
(2605, 'Camajuaní', 26),
(2606, 'Caibarien', 26),
(2607, 'Remedios', 26),
(2608, 'Placetas', 26),
(2609, 'Santa Clara', 26),
(2610, 'Cifuentes', 26),
(2611, 'Santo Domingo', 26),
(2612, 'Ranchuelo', 26),
(2613, 'Manicaragüa', 26),
(2701, 'Aguada de Pasajeros', 27),
(2702, 'Rodas', 27),
(2703, 'Palmira', 27),
(2704, 'Lajas', 27),
(2705, 'Cruces', 27),
(2706, 'Cumanayagua', 27),
(2707, 'Cienfuegos', 27),
(2708, 'Abreus', 27),
(2801, 'Yaguajay', 28),
(2802, 'Jatibonico', 28),
(2803, 'Taguasco', 28),
(2804, 'Cabaiguán', 28),
(2805, 'Fomento', 28),
(2806, 'Trinidad', 28),
(2807, 'Sancti Spiritus', 28),
(2808, 'La Sierpe', 28),
(2901, 'Chambas', 29),
(2902, 'Morón', 29),
(2903, 'Bolivia', 29),
(2904, 'Primero de Enero', 29),
(2905, 'Ciro Redondo', 29),
(2906, 'Florencia', 29),
(2907, 'Majagua', 29),
(2908, 'Ciego de Ávila', 29),
(2909, 'Venezuela', 29),
(2910, 'Baraguá', 29),
(3001, 'Carlos Manuel de Céspedes', 30),
(3002, 'Esmeralda', 30),
(3003, 'Sierra de Cubitas', 30),
(3004, 'Minas', 30),
(3005, 'Nuevitas', 30),
(3006, 'Guáimaro', 30),
(3007, 'Sibanicú', 30),
(3008, 'Camagüey', 30),
(3009, 'Florida', 30),
(3010, 'Vertientes', 30),
(3011, 'Jimaguayú', 30),
(3012, 'Najasa', 30),
(3013, 'Santa Cruz del Sur', 30),
(3101, 'Manatí', 31),
(3102, 'Puerto Padre', 31),
(3103, 'Jesús Menéndez', 31),
(3104, 'Majibacoa', 31),
(3105, 'Las Tunas', 31),
(3106, 'Jobabo', 31),
(3107, 'Colombia', 31),
(3108, 'Amancio', 31),
(3201, 'Gibara', 32),
(3202, 'Rafael Freyre', 32),
(3203, 'Banes', 32),
(3204, 'Antilla', 32),
(3205, 'Báguanos', 32),
(3206, 'Holguín', 32),
(3207, 'Calixto García', 32),
(3208, 'Cacocum', 32),
(3209, 'Urbano Noris', 32),
(3210, 'Cueto', 32),
(3211, 'Mayarí', 32),
(3212, 'Frank País', 32),
(3213, 'Sagua de Tánamo', 32),
(3214, 'Moa', 32),
(3301, 'Río Cauto', 33),
(3302, 'Cauto Cristo', 33),
(3303, 'Jiguaní', 33),
(3304, 'Bayamo', 33),
(3305, 'Yara', 33),
(3306, 'Manzanillo', 33),
(3307, 'Campechuela', 33),
(3308, 'Media Luna', 33),
(3309, 'Niquero', 33),
(3310, 'Pilón', 33),
(3311, 'Bartolomé Masó', 33),
(3312, 'Buey Arriba', 33),
(3313, 'Guisa', 33),
(3401, 'Contramaestre', 34),
(3402, 'Mella', 34),
(3403, 'San Luis', 34),
(3404, 'Segundo Frente', 34),
(3405, 'Songo la Maya', 34),
(3406, 'Santiago de Cuba', 34),
(3407, 'Palma Soriano', 34),
(3408, 'Tercer Frente', 34),
(3409, 'Guamá', 34),
(3501, 'El Salvador', 35),
(3502, 'Manuel Tames', 35),
(3503, 'Yateras', 35),
(3504, 'Baracoa', 35),
(3505, 'Maisí', 35),
(3506, 'Imías', 35),
(3507, 'San Antonio del Sur', 35),
(3508, 'Caimanera', 35),
(3509, 'Guantánamo', 35),
(3510, 'Niceto Pérez', 35);

INSERT INTO patients (id, first_name, last_name, identifier, birthdate, gender, address, municipality_id) VALUES
('3a59c8e4-a6eb-48be-b4d0-552cf9b4721a', 'Rayda', 'Matrapa Mastrapa', '67081619736', '1967-08-16 00:00:00', 'female', 'Alto Cedro. Cueto', 3210),
('18abeffc-b4f6-441d-aac1-c879d335f7b9', 'Yanet', 'Leyva Hernandez', '76042416247', '1976-04-24 00:00:00', 'female', 'C 5ta Pueblo Nuevo', 3206),
('4efd1e0c-adbe-4b3f-b813-6fb05fde7d6b', 'Nevis de la', 'Encarnacion pupo', '43052021750', '1943-05-20 00:00:00', 'female', 'C C entre B y F No 26.rafael freyre holguin', 3202),
('eb8cdbd1-1a05-4225-933d-b5ce76d97c8e', 'Yamilet', 'vega Almaguer', '76022416358', '1976-02-24 00:00:00', 'female', 'Cacocum', 3208),
('9c7a2b32-2d02-44ff-af3c-77e7cb96695b', 'Fomelio', 'Ferias Mejias', '40092511007', '1940-09-25 00:00:00', 'male', 'Peralta', 3206),
('a6f266d4-02e5-461c-b49b-464fc6f64e1a', 'Antonio gerardo', 'Claro Fernandez', '42120500601', '1942-12-05 00:00:00', 'male', 'Urbano Noris', 3209),
('588fa174-628e-4896-9858-90547b890f37', 'roberto', 'Rodriguez duran', '50050517463', '1950-05-05 00:00:00', 'male', 'Miguel Glez No 11 Cacocum', 3208),
('2db34360-86d9-435a-8786-fd87bd2fc2fc', 'Eddy', 'Legra Díaz', '40052008048', '1940-05-20 00:00:00', 'male', 'C 26 No 20 Esquina 5 Alcides Pino', 3206),
('9f66071d-9d72-4396-ad68-89f90d53b353', 'Maria de los Angeles', 'Parra Góngora', '64080604074', '1964-08-06 00:00:00', 'female', 'Calle 27 No 48 entre ( y Gonzalez valdes Salida de San Andres', 3206),
('1f6dd454-3ed5-4677-b26b-9fd9cfda96c9', 'Ana Cristina', 'Pantoja ramirez', '58072622391', '1958-07-26 00:00:00', 'female', 'Guisa Granma', 3313),
('81493913-2af0-42ff-91b6-4ef62a703b50', 'Digna', 'Escobar Zayas', '69092620057', '1969-09-26 00:00:00', 'female', 'Calle 12 edificio 363 apto 6 Alex Urquiola', 3206),
('ede9a36d-d809-42f2-98d2-7d5d94adce2d', 'Luis Daniel', 'Casanova Almaguer', '87032525782', '1987-03-25 00:00:00', 'male', 'Calle 3 no 108 entre 10 y 18 Pueblo Nuevo', 3206),
('3a8dae35-eb02-45a2-80ae-a704902f26e0', 'Liliana', 'Perez Rivero', '83121219496', '1983-12-12 00:00:00', 'female', 'Calle 10 no 25 entre 3 y Cardet Pueblo Nuevo', 3206),
('7de45fdd-ac06-4b68-9530-6d599328a7ad', 'Doralis', 'Invernón Rodriguez', '70072824078', '1970-07-28 00:00:00', 'female', 'Aguada la Piedra Rafael Freyre', 3206),
('f851650e-bdd3-47fd-8c52-6bcdb87cd6d9', 'Lilia', 'Escalona Norada', '90052641171', '1990-05-26 00:00:00', 'female', 'Velasco', 3206),
('39928f0d-38c8-4ce7-b7cf-88290503b342', 'Julián', 'Perez Caisal', '45021805844', '1945-02-18 00:00:00', 'male', 'Edificio 39 apto 31', 3206),
('464034b3-7dd4-44e0-8161-cfd6e2650eab', 'Madelín', 'Pavón García', '75112316150', '1975-11-23 00:00:00', 'female', 'Calle 7  no 53 entre 8 y 10. Pueblo Nuevo', 3206),
('f473399d-add8-437d-ab1f-54e491cc8d2c', 'Arelys', 'Sánchez Leyva', '65122621274', '1965-12-26 00:00:00', 'female', 'Calixto García', 3206),
('0357093f-9ac8-4619-8348-e8a12be7cfc6', 'Maribel', 'Rojas Tejeda', '72122126479', '1972-12-21 00:00:00', 'female', 'Floro Perez', 3206),
('21d72bea-686c-4834-8e7b-bb7438409910', 'Marialin', 'laguna Hecheverria', '86061521651', '1986-06-15 00:00:00', 'female', 'C 52 no 18 A entre 27 y 15 Nuevo Llano', 3206),
('649574c4-3843-4fc8-a44c-f666c33ff71e', 'Luis Enrique', 'Cabrera Velazquez', '71091209228', '1971-09-12 00:00:00', 'male', 'Comunidad Cocal 55 Reparto militar', 3206),
('4475ce8a-0864-4e01-b73d-92c01a937ba7', 'Tomas', 'Guerra Calzadilla', '67091819689', '1967-09-18 00:00:00', 'male', 'C 5ta No 14 Fidelidad Cacocum', 3208),
('07c1c5ea-c8ef-41da-b4ff-22e91d023fa6', 'Maria Emilia', 'Matos Calzadilla', '56032411375', '1956-03-24 00:00:00', 'female', 'Sagua de Tanamo', 3213),
('0db6c578-b63a-4e3d-a7b5-784dcd8fa584', 'Ramon', 'Ricardo Pineda', '58101816601', '1958-10-18 00:00:00', 'male', 'Barri nPozo Redonda Cauto Cristo Granma', NULL),
('4647c499-3039-4a3a-b1e1-0d34d80c1d59', 'Carmen', 'Almaguer Bidu', '64126009076', NULL, 'female', 'calle 4ta N9', 3206),
('63f9c5a9-bce7-44c6-bc0a-cc9761765007', 'Cefedro', 'Estupiñan Sarmiento', '30060406600', '1930-06-04 00:00:00', 'male', 'Camino Militar N21', 3206),
('30e7d74d-905f-4303-8c77-7bc83cb6cec6', 'Enelvis', 'Sanchez Hechavarria', '75052416175', '1975-05-24 00:00:00', 'male', 'Calle Jose A N71 Alex Urquiola', 3206),
('175c94d4-3dc0-47d7-94c8-e9ba95e8d2c7', 'Neisa', 'Leyva Suarez', '76081031175', '1976-08-10 00:00:00', 'female', 'Sagua de Tanamo', 3206),
('6ac9ead6-4049-48a1-a1d0-640bc0dfbecc', 'Lizandra', 'Diaz Cabrera', '85061221618', '1985-06-12 00:00:00', 'female', 'Calle 19 N29 Villa Nueva', 3206),
('5cbe172f-52d3-4bf3-bbf1-e7fb952867e9', 'Juan', 'Fernández Suárez', '32040906507', '1932-04-09 00:00:00', 'male', 'C Narcizo garcia no 38 Entre 5 y 7 º', 3206),
('3f85ba01-1b33-4c05-912e-8b323bed21b0', 'Emélides', 'Higueras Ramírez', '36121706111', '1936-12-17 00:00:00', 'female', 'La pelota Báguanos Holguín', 3205),
('5a3a8a08-8183-4537-ac78-095ab93e7151', 'Yudith', 'Santiesteban Pérez', '73123106811', '1973-12-31 00:00:00', 'female', 'Naranjo, Purnio. San Andrés.', 3206),
('c223c305-f9d6-4de5-96ef-903d1b3ab9d1', 'Yurisleydi', 'Alarcón Días', '84030420670', '1984-03-04 00:00:00', 'female', 'C/14 No. 9 /3ra y 7ma. Rep. Ramón Quintana', 3206),
('4a362885-b477-419b-b19b-979d9bce80b0', 'Alfredo', 'Domínguez Suárez', '72030709989', '1972-03-07 00:00:00', 'male', 'Calle 10 /9 y 11 No. 31 Ciudad Jardín', 3206),
('867b97f7-b458-44d2-8dcd-ea27b241f048', 'Marianela', 'Mastrapa Cedeño', '91120242357', '1991-12-02 00:00:00', 'female', 'CPA Antonio Maceo', 3206),
('95494c0e-ef90-437a-aaf3-2d4880fbc829', 'Nelcida', 'Reyes Consuegra', '68101125931', '1968-10-11 00:00:00', 'female', 'Vista Alegre. Bijarú. Báguano', 3206),
('fca9cd94-0fd8-47d2-beac-3dd4d64daeff', 'Yunia', 'Ávila Rodríguez', '74110536852', '1974-11-05 00:00:00', 'female', 'Velazco', 3206),
('3eeb3a88-eb6b-4858-a545-aa42cfb8a839', 'Anabel', 'Tamayo Marrero', '71040688259', '1971-04-06 00:00:00', 'female', '8va No. 15, Cacocún', 3206),
('7b87e45a-e816-4ee2-8067-b59da2526c48', 'Eloima', 'Rojas Amado', '58060107254', '1958-06-01 00:00:00', 'female', 'Calle: 9na No. 51 A Cacocúm', 3206),
('644d560f-0256-4dfb-a738-b178f8effdb8', 'Manuel', 'Peréz Martínez', '51120611847', '1951-12-06 00:00:00', 'male', 'Yuraguana. San Andrés', 3206),
('7f85cc90-f6bc-45b3-82a4-bacf430d75a7', 'Miguel', 'Valázquez Caballero', '73042821940', '1973-04-28 00:00:00', 'male', 'Jesús Menéndez. Las tunas', NULL),
('0ccc80fb-2cd2-4375-a4e4-a6eb1d458e8f', 'Arletti', 'Cedeño Escalona', '96122920192', '1996-12-29 00:00:00', 'female', 'C 17 no 9 entre 6 y F La quinta', 3206),
('da793574-c910-475b-9532-894bc87dfcac', 'Anabel', 'Caballero Diéguez', '73020606918', '1973-02-06 00:00:00', 'female', 'Júpiter, Las Brisas Calixto García', 3207),
('0145060f-1261-46d8-80a8-f2728dd73d74', 'Dania', 'domínguez Fonseca', '63020512218', '1963-02-05 00:00:00', 'female', 'Las brisas, Calixto García', 3207),
('fbc5e5b8-5261-48a9-9076-4c695adbbf50', 'Alexis', 'Serrano Rodríguez', '78052725482', '1978-05-27 00:00:00', 'male', 'La Caridad Buenaventura', 3207),
('ee35d41b-e1c0-41ae-931a-cb4d319fe62e', 'Yasel', 'Pérez Pupo', '73031106816', '1973-03-11 00:00:00', 'female', 'Palmito San Agustín Calixto García', 3207),
('3fefdd2c-7309-41a3-a385-ee095cd8aec4', 'Daimi', 'Domínguez Castillo', '86082021632', '1986-08-20 00:00:00', 'female', 'Calle Manuel Angulo no65 Rpto 26 de Julio', 3206),
('6c180484-a1db-413d-9792-635bb721e798', 'Eraides', 'Rosabal Torres', '45060306390', '1945-06-03 00:00:00', 'female', 'C 23 no 39 entre 40 y 2 Alcides Pino', 3206),
('55a74992-b9cf-493e-b010-4d5b0c2ef216', 'Yadira', 'Moralez Pe', '84101421690', '1984-10-14 00:00:00', 'female', 'C Josefina guerra no15 Rpto Zayas', 3206),
('365d15ad-71fc-4833-ab70-73fb56ce5434', 'Franklin', 'Leyva Pérez', '81011619247', '1981-01-16 00:00:00', 'male', 'Calle 15 no26 entre 12 y 20 Nuevo Llano', 3206),
('4e2760e9-68ea-494e-92b7-552e3eadc227', 'Joan Miguel', 'González Parra', '76091810185', '1976-09-18 00:00:00', 'male', 'Calle 7 no 7 Rpto Libertad', 3206),
('0e50122c-ae17-4dd3-8cac-1037a87af26b', 'Ledemila', 'Molina Almarales', '89011837693', '1989-01-18 00:00:00', 'female', 'Pueblo Nuevo', 3206),
('2fd0c6ca-0109-48a6-be66-05947557449c', 'Mirtha', 'González Ricardo', '55031415241', '1955-03-14 00:00:00', 'female', 'nan', 3206),
('c076f208-efa5-49b9-bbdd-e7a64dd4636f', 'Juan Pablo', 'López Majes', '48063006603', '1948-06-30 00:00:00', 'male', 'Cayo Cedro Maceo Báguanos', 3206),
('83a2ccc9-ecfb-4744-b00b-b947f3d024bb', 'Inais', 'Moreno Yaqui', '69012907314', '1969-01-29 00:00:00', 'female', 'Avenida Los Álamos no 23', 3206),
('5c0b5f2b-0ddb-40e3-a007-5bd4a146138d', 'Vivian', 'Cruz Tano', '66053006730', '1966-05-30 00:00:00', 'female', 'Calle: 12 No. 1 B Pedro Díaz Coello', 3206),
('99d303cb-7d66-4e81-a443-6bb33c93f19b', 'Yoleidis', 'Blanco Blanco', '89090212294', '1989-09-02 00:00:00', 'female', 'El Uso. Velazco', 3206),
('1a14419e-75c3-41b6-8b6d-011064b34706', 'Yailén', 'Leyva Morales', '91061142353', '1991-06-11 00:00:00', 'female', 'Arnaldo Blanco Morales, Cacocum', 3208),
('c74cc78c-1396-466d-bf24-d2cb4eacd6b5', 'Bárbara', 'Batista Paneque', '69061423850', '1969-06-14 00:00:00', 'female', 'Calle 16 No. 10/13y final. Alcides Pino', 3206),
('1c9af52a-b1f0-49cd-8928-848928e751c5', 'Yasmina', 'Laera Pupo', '88091326110', '1988-09-13 00:00:00', 'female', 'Los Güines. Velazco', 3206),
('3c1fd883-6275-4665-aa4e-5ec98ec3054e', 'Deisi', 'Ramírez Borges', '92102943394', '1992-10-29 00:00:00', 'female', 'Sala de perinatología, cama 3', 3206),
('5de04d47-cef5-46af-9f28-d323f91b79e9', 'Claudia', 'María Fernández', '01040979094', '2001-04-09 00:00:00', 'female', 'Vista Alegre', 3206),
('d57da2a3-2596-425e-a012-94fb58ea04c3', 'Marlenis', 'Tamayo Calzadilla', '69081002854', '1969-08-10 00:00:00', 'female', 'El Caro, Sagüa de Tánamo.', 3213),
('3e23f4c7-bc02-454a-945d-f074a4a049f4', 'Melchor', 'Tamayo Ávila', '47010620548', '1947-01-06 00:00:00', 'male', 'Naranjo de purnio, Holguín', 3206),
('7d8a8130-fbaf-4b3e-beab-477957b7fef9', 'Ana Maria', 'González Hernández', '54122507556', '1954-12-25 00:00:00', 'female', 'Reynerio Almaguer no 11 Rpto Sanfiel', 3206),
('a50a5d19-b8ed-42e8-813a-026b0f0af9b9', 'Narciso', 'Montero Guerrero', '60122406441', '1960-12-24 00:00:00', 'male', 'Calle 37 no 14 Ramon Quintana', 3206),
('e57c2e66-2750-4976-b7d6-bdf1b0cc9f65', 'Lorenza', 'Domínguez Estupiñán', '40091507097', '1940-09-15 00:00:00', 'female', 'C 3ra Vista Alegre Cacocum', 3208),
('11111786-40ed-4e08-afb9-28a53637719f', 'Ana Mirtha', 'Pérez Leyva', '47082807912', '1947-08-28 00:00:00', 'female', 'Luz Marrero no 79', 3206),
('047ef0fd-e4b3-49e0-8a25-10bfe3c57619', 'Roger', 'Fuentes Borrego', '52091605076', '1952-09-16 00:00:00', 'male', 'C 2 No 1 Pedro Díaz coello', 3206),
('4908ad9a-7205-48f8-8297-58836a333151', 'Yordanka', 'Jorge Carralero', '76032216158', '1976-03-22 00:00:00', 'female', 'C 10 de octubre no 26 Rpto Harlem', 3206),
('efd28e85-35e7-4f79-aaf5-d2ef466bcaf1', 'José Miguel', 'Sánchez Herrera', '63122010669', '1963-12-20 00:00:00', 'male', 'Calle Mariana d la torre no114 El Llano', 3206),
('88ce17ba-0217-4209-998b-22abbbbaa9a7', 'Deysi', 'Rodríguez Compte', '49101802837', '1949-10-18 00:00:00', 'female', 'Manzanillo Granma', 3306),
('85007cf3-d009-4432-b1c4-9e4ab40a23f9', 'Mayra', 'Rodríguez Rodríguez', '63030614232', '1963-03-06 00:00:00', 'female', 'Banes Holguin', 3203),
('826980a4-94eb-4373-bbde-59e542f146c3', 'Elsa Clementina', 'Osorio Osorio', '47112307074', '1947-11-23 00:00:00', 'female', 'Capitan Urbino calle 8 el Llano', 3206),
('89fc6a76-bbc8-48e3-9656-bd87937d237a', 'Candida', 'Leyva Aldolgro', '90110641314', '1990-11-06 00:00:00', 'female', 'Yaguazo', 3208),
('bc6feed3-c202-450f-a5f0-bc26a663bcec', 'Vivian', 'Aguilar Vega', '70041208218', '1970-04-12 00:00:00', 'female', 'C General feria no 22f entre Colon y Carretera de Gibara', 3206),
('0dac145f-a321-432b-b72b-3770a1be6120', 'Digna Valentina', 'Ruiz Oca', '65091615875', '1965-09-16 00:00:00', 'female', 'c 12 edificio 32 apto H entre Mariana de la Torre y 11 Rpto Lenin', 3206),
('ba5406e0-91ef-4776-acc0-e04df85efd02', 'Martha', 'Sánchez González', '70082723614', '1970-08-27 00:00:00', 'female', 'C1ra edificio 116 apto 2.Melilla Freyre', 3202),
('b9480e76-1a3b-4bf8-934c-862147089662', 'Rafael', 'Serrano Coello', '66090915289', '1966-09-09 00:00:00', 'male', 'C Julio Antonio Mella Rpto 26 de julio no 43', 3206),
('8ba17fc7-1e31-4c0b-a6a2-03f6c632b06e', 'Julia', 'García López', '63110318475', '1963-11-03 00:00:00', 'female', 'La Esperanza . Calixto García', 3206),
('d52eaf0b-49aa-42c7-bdb9-84753684db6f', 'Ivia', 'Almira Grave', '79061919578', '1979-06-19 00:00:00', 'female', 'C 78 no 49 Rpto Hecheverria.Mayarí', 3211),
('da81cba5-9a47-4405-bde3-12d69f957204', 'Delmi', 'Peña Peña', '70031205859', '1970-03-12 00:00:00', 'female', 'Banes Barrio Vega de Mella', 3203),
('1f3b2648-259e-4a80-acc0-6a088abcbf77', 'Mileydis', 'Tamayo Téllez', '73092911795', '1973-09-29 00:00:00', 'female', 'C 11 no 2021 entre 20 y 22 San Germán', 3209),
('150fd6ad-1d97-4c81-a8c5-c0c3fbf37113', 'Magalys C.', 'Pupo Muñoz', '66012009070', '1966-01-20 00:00:00', 'female', 'Los Pinos Fray Benito Rafael Freyre', 3202),
('40e557a5-b748-44ea-ab67-554c4a15ffcd', 'Xiomara', 'García Parra', '72021207776', '1972-02-12 00:00:00', 'female', 'C 12 no 33f1 entre 1era y 3era.Piedra Blanca', 3206),
('e088a9c6-84ef-424d-bd0b-9b769d414d24', 'Julio', 'Tamayo Ramires', '70031210367', '1970-03-12 00:00:00', 'male', 'Santa Rosa S/N Rafael Freire', 3206),
('6974a5c8-41e2-479d-9c63-80c01343c3d9', 'Judit', 'Santiesteban Perez', '75125106811', NULL, 'female', 'San Andres', 3206),
('d8bdbf55-4c1c-464f-a627-baf0630aa3c6', 'Julio', 'Hernández Feria', '49052710272', '1949-05-27 00:00:00', 'male', 'holguin', NULL),
('e8025a36-4ae2-4176-85f0-8ec45ee23be3', 'Idalse', 'Batista Cinta', '65052991990', '1965-05-29 00:00:00', 'female', 'Levisa, Mayarí', NULL),
('dd1190c3-5970-451c-8775-cb78259d265d', 'Jose Alberto del', 'Río Batista', '47091503525', '1947-09-15 00:00:00', 'male', 'Carretera central Km 71, Holguín', NULL),
('570c4124-dded-4248-b08d-bbb217ba467b', 'Armerio', 'Ávila Hecheverría', '51111907184', '1951-11-19 00:00:00', 'male', 'San Andrés', NULL),
('d8abc800-fc06-476e-941f-7c931856c77f', 'Ofelio', 'Salso Velázquez', '32070106137', '1932-07-01 00:00:00', 'male', 'Maceo No 2, El Llano', NULL),
('5b917091-ed1d-40c5-b0b0-9c5efd13e459', 'Julio', 'Suárez Betancourt', '36011202582', '1936-01-12 00:00:00', 'male', 'Cristino Naranjo, Cacucum', NULL),
('4dc80361-e524-4e01-a6e4-498a3bbccdb1', 'Juan Jiménez de', 'la Torre', '30111404800', '1930-11-14 00:00:00', 'male', 'Areopuerto Militar, Holguín', NULL),
('f903150c-0b7c-466c-b6a4-37305d7de70a', 'Marlenis', 'Leyva Lorenzo', '61092306758', '1961-09-23 00:00:00', 'female', 'Banes', NULL),
('b3a892dd-0455-4b1d-9d06-8dd77516303d', 'Darly', 'Sánchez Parra', '96113021850', '1996-11-30 00:00:00', 'female', 'Calle Mayabe', NULL),
('d3f17781-8708-46c8-a71e-86d007f38062', 'Maité', 'Saíz Rolecia', '79111019010', '1979-11-10 00:00:00', 'female', 'Báguano', NULL),
('2be7bb03-6d04-4a3e-a52a-f454fa72bb1f', 'Elizabeth', 'Martínez Calderón', '75050247734', '1975-05-02 00:00:00', 'female', 'Güirabo', NULL),
('f09ccd74-88d2-4a17-b57b-5314ce72ef4b', 'Maritza', 'Acosta Morales', '71041308234', '1971-04-13 00:00:00', 'female', 'Maceo', NULL),
('2b76d48d-b628-49dc-bc4c-b704b6f1d995', 'Mailín', 'Báez Hernández', '71031107856', '1971-03-11 00:00:00', 'female', 'Palmarito, Báguano', NULL),
('89a3abbf-f96c-4a9c-8224-583dd86854b5', 'Eva', 'Julia Cuadrado', '74100414498', '1974-10-04 00:00:00', 'female', 'Camilo Cienfuegos No 7, Velazco', NULL),
('bd39029a-c392-41d9-a67d-712e01b24e48', 'Nathaly', 'Blanco Abreu', '91060322497', '1991-06-03 00:00:00', 'female', 'Calle progreso 197 A Vista Alegre', 3206),
('c106e59b-0269-4196-8a2c-b4de83205109', 'Caridad', 'Vazquez Soto', '72090823526', '1972-09-08 00:00:00', 'female', 'Marcané', 3210),
('4ea31b9c-ed08-4a85-91ea-b61611f615d0', 'Carlos', 'Riandis Puig', '67111508924', '1967-11-15 00:00:00', 'male', 'Garayalde Edificio 337 Apto b', 3206),
('b35cbfde-03d0-4e39-a603-6c0a597a1ae3', 'Yamaisa', 'Hidalgo García', '73112902319', '1973-11-29 00:00:00', 'female', 'Máximo Gómez no 60 entre 12 y 12', 3206),
('afff462a-006e-4d16-87d0-9d2acb04713f', 'Yaima', 'Pérez Santana', '81020318719', '1981-02-03 00:00:00', 'female', 'Bloque 3a ampliacion 21 de abril', NULL),
('7f4fbfc3-8c1e-4e9c-93b6-0b690a084cee', 'Naldys', 'Ruiz Cortiña', '72051619458', '1972-05-16 00:00:00', 'female', 'C Porvenir Edificio I apto 32 Marcané', 3210),
('32e78fb4-ea60-4541-aa37-2e915f5eca4a', 'Anays', 'Estrada Menéndez', '71101030591', '1971-10-10 00:00:00', 'female', 'A no 37 Evia Sur Birán Cueto', 3210),
('284d7ea0-e81e-4ea3-be7e-82fec1f6ec92', 'Denia', 'Vallejo Céspedes', '67102908492', '1967-10-29 00:00:00', 'female', 'Calle 23 no 497', 3210),
('4a014166-06bd-4994-9c8e-880de2f87449', 'Juan Javier', 'Parra Alvarez', '49120307060', '1949-12-03 00:00:00', 'male', 'Calle 29 No. 26 entre 16 y 18 pueblo nuevo', 3206),
('f342afa3-0cfc-4bda-89c7-9e7b7dbf008f', 'Nilda', 'Suarez Feria', '59092010733', '1959-09-20 00:00:00', 'female', 'El Manguito', 3205),
('856db182-8f62-4da5-bd6e-423f5625c56a', 'Lisyanis de la', 'Rosa Eliz', '88050626658', '1988-05-06 00:00:00', 'female', '1ra No. 11', 3206),
('f83efbb4-8b13-4184-ad05-741b84556044', 'Osiris', 'Pérez Días', '71081623111', '1971-08-16 00:00:00', 'female', 'Calle 6 NO. 72 Justo Aguilera, Jarlen', 3206),
('5d85f709-d051-42ac-a9d5-77c357510eab', 'Yelenis', 'Amet Amet', '75040816205', '1975-04-08 00:00:00', 'male', 'Edif. 8 Comunidad Militar Ramón Qintana', 3206),
('9aecf405-e302-4763-b4aa-197aa444b5af', 'Eday', 'Urrutia Mariño', '55100709082', '1955-10-07 00:00:00', 'male', 'Edif. 16 Ato. 10', 3214),
('3c66cb94-f289-4550-a24f-01c5a5f9d373', 'nan', 'Luci Días', '57052007310', '1957-05-20 00:00:00', 'female', 'Calle 17 No. 69 Entre Capitan Urbino y 12 Nuevo Llano', 3206),
('adb0afcf-fdb5-4ada-9384-1f6d0a080c7c', 'Enelvis', 'Sanchez Hechebarría', '75052416177', '1975-05-24 00:00:00', 'female', 'Calle Independencia No. 8', 3208),
('3e127f2e-f628-4241-9ad4-16e080f599c4', 'Yilian', 'Almenares Estupiñán', '82110426057', '1982-11-04 00:00:00', 'female', 'Carretera Mirador, Km 4, Mayabe', NULL),
('a5efa4d7-33ba-45ec-b335-c7bcc7353540', 'Silbelis', 'Montejo García', '57021408272', '1957-02-14 00:00:00', 'male', 'Calle 12 No 338 B. Rpto Emilio Bárcenas', NULL),
('ab3b97b9-37d2-42bb-a2c2-39c9d72abaa5', 'Aimé María', 'Mayán Sardain', '85042958776', '1985-04-29 00:00:00', 'female', 'Peralejo No 24, Rpto Peralta', NULL),
('2c442775-7901-4cbf-9ef8-656213f7cc4a', 'Ania', 'Estupiñán Ramírez', '69111814658', '1969-11-18 00:00:00', 'female', 'Calle 1ra No 65, Rpto Luz', NULL),
('8ead9860-1c86-4e85-8463-5d360cb9971f', 'Gloria', 'Reyes Alfonso', '69082101310', '1969-08-21 00:00:00', 'female', 'Calle Almaguer No 7, A. Urqueola', NULL),
('be78f18b-dabd-4ee8-8dc0-c778ac26af26', 'Arelis', 'Quevedo García', '81060418436', '1981-06-04 00:00:00', 'female', 'Calle E no 5, Cacocum', NULL),
('d288f22c-ed6d-4c2a-a871-37381c953574', 'Marilín', 'Pedralles Rubio', '74042214590', '1974-04-22 00:00:00', 'female', 'San Andrés', NULL),
('9d698f96-9897-44c2-9f66-02d874e40c2f', 'Mayumi', 'Reyes Pralada', '86031922518', '1986-03-19 00:00:00', 'female', 'Birán', NULL),
('2af2144d-f8a2-4b63-a908-a4af8999d35f', 'Odalis', 'Gracía Pérez', '72032608236', '1972-03-26 00:00:00', 'female', 'Cacocúm', NULL),
('c153f105-b5f0-49b1-91a7-580c71f4f00b', 'Marilín', 'Nápoles A.', '75020938559', '1975-02-09 00:00:00', 'female', 'Cacocúm', NULL),
('86efe837-98a5-4fb1-90af-4ddd3451bf92', 'Mairel', 'Reyes Martínez', '74122336616', '1974-12-23 00:00:00', 'female', 'Edif 2 Apto 8, Cueto', NULL),
('33fb1d87-1ad3-4ba3-a96e-eaddbbbc5121', 'Ana Rosa', 'Larduet Núñez', '70080906779', '1970-08-09 00:00:00', 'female', 'Marcané., calle No 2 , No 16', NULL),
('b5276a03-c03f-4631-86bf-90af53ff2e6f', 'Damaris', 'Milanés Galindo', '73031418776', '1973-03-14 00:00:00', 'female', 'Barrio Rubio No 2 Cacocum', NULL),
('f2eb0e60-bfef-4c63-8e08-4f04ddb6bcda', 'Ariannis Beatriz', 'Guena Arias', '84100421777', '1984-10-04 00:00:00', 'female', 'Calle 5ta No 17 F Entre 10 y Ave Libertadores', NULL),
('7ef0a679-7aa9-4144-8eee-c11107547420', 'Maricela', 'Pérez Zamora', '90020441537', '1990-02-04 00:00:00', 'female', 'Calle 18 Nom 64, Marcané', NULL),
('714d741f-acb1-43a2-81ef-14cce4556fa6', 'Idalmis', 'Quiala Ramírez', '68101015839', '1968-10-10 00:00:00', 'female', 'Calle 7 de Diciembre No 90, Cueto', NULL),
('10ef1812-bf2c-4a78-80f9-55b0e65abbad', 'Raquel', 'Gadales Mendoza', '69020323419', '1969-02-03 00:00:00', 'male', 'calle 8 no 30 los guillenes', NULL),
('8e2de783-b3ac-4629-9017-ff814645f946', 'Marinelis', 'Escalante Rodríguez', '73100116415', '1973-10-01 00:00:00', 'female', 'Calle 7 no 261 Baraguá', 3210),
('deb78b7b-2891-4b75-8a52-9e3a329f9f40', 'Ada', 'Abreu Pineiro', '61041813231', '1961-04-18 00:00:00', 'female', 'Calle 36 no 2431 entre 3 y 35 San Germán', 3210),
('c3e2bac8-a68d-4af3-a73a-f33b9d65137e', 'Arisney', 'Torres Torres', '76061834014', '1976-06-18 00:00:00', 'female', 'nan', NULL);

INSERT INTO biopsies (id, number, patient_id, sample, entry_date, macroscopic_date, microscopic_date, clinical_diagnosis, anatomopathological_report) VALUES
('d8b9886c-de9f-4399-846c-b54b6c051851', '6195', '3a59c8e4-a6eb-48be-b4d0-552cf9b4721a', 'piel', NULL, '2019-10-21', '2019-10-21', 'Queratoacantoma del antebrazo derecho', 'Carcinoma epidermoide bien diferenciado infiltrante completamente resecado'),
('6862e5dc-a748-4b6a-b83c-9187b4996c50', '6194', '18abeffc-b4f6-441d-aac1-c879d335f7b9', 'Piel', NULL, '2019-10-21', '2019-10-21', 'Carcinoma basal de piel', 'Quiste de inclusión epidérmica completamente resecado'),
('59a56fac-e23b-4b4a-baee-467484fecf52', '6193', '4efd1e0c-adbe-4b3f-b813-6fb05fde7d6b', 'piel', NULL, '2019-10-21', '2019-10-21', 'carcinoma basal de mejilla', 'carcinoma basal completamente resecado'),
('346b5cf3-f1d7-40af-bd7b-691a79ebc938', '6192', 'eb8cdbd1-1a05-4225-933d-b5ce76d97c8e', 'piel', NULL, '2019-10-21', '2019-10-21', 'Carcinoma basal', 'Queratosis sebprreica completamente resecado'),
('4b5f8a0c-0c1d-424c-93a2-ff228cd0ed01', '6191', '9c7a2b32-2d02-44ff-af3c-77e7cb96695b', 'piel', NULL, '2019-10-21', '2019-10-21', 'Carcinoma basal de mejilla izquierda', 'Carcinoma basal sólido completamente resecado'),
('0a40606f-274e-49ad-b107-780a41404df9', '6189', 'a6f266d4-02e5-461c-b49b-464fc6f64e1a', 'piel', NULL, '2019-10-21', '2019-10-21', 'Carcinoma basal', 'Carcinoma basal pigmentado completamente resecado'),
('84c30f34-e1bc-4c31-8376-e8c8d0e97578', '6167', '588fa174-628e-4896-9858-90547b890f37', 'Riñon derecho con grasa perirrenal', NULL, '2019-10-18', '2019-10-18', 'Tumor renal derecho', 'Nefrectomia derecha donde se onserva carcinoma renal de células claras  no infiltra vasos, ni ureter, se examina tejido graso donde no se observa adenopatía.'),
('fdee190a-4105-46a2-be66-46accc4dea5c', '6179', '2db34360-86d9-435a-8786-fd87bd2fc2fc', 'Piel', NULL, '2019-10-21', '2019-10-21', 'Carcinoma basal ulcerado', 'Carcinoma basal completamente resecado'),
('2f4e1eb7-e16d-4383-8418-af7b3c09c6bd', '6106', '9f66071d-9d72-4396-ad68-89f90d53b353', 'T de Partes Blandas', NULL, '2019-10-21', '2019-10-21', 'T de partes blandas de brazo izquierdo', 'Lipoma completamente resecado'),
('2225ec66-ddad-4260-857a-1c109c9f6154', '5675', '1f6dd454-3ed5-4677-b26b-9fd9cfda96c9', 'Tejido oseo', NULL, '2019-10-17', '2019-10-17', 'T osea de Femur izquierdo', 'Favor enviar estudios imagenologicos'),
('79eb55bd-ffdc-49a3-b359-8f4f974bd8bc', '5817', '81493913-2af0-42ff-91b6-4ef62a703b50', 'Pólipo de cuello uterino', NULL, '2019-10-21', '2019-10-21', 'polipo de cuello uterino', 'Biopsia donde se observa pólipo endocervical'),
('dfbb1b97-032e-4fc3-8ee9-e61e2b412f23', '6067', 'ede9a36d-d809-42f2-98d2-7d5d94adce2d', 'Dedo Izquierdo', NULL, '2019-10-17', '2019-10-17', 'Masa tumoral de dedo izquierdo', 'muestra donde no se observa el tejido conectivo con células gigantes que caracteriza el tumor de vaina tendinosa, el aspecto histológico es compatible con T cartilaginosa tipo condroide benigno.'),
('7ef94ffa-e60f-4a2c-970b-c2152ea58669', '5863', '3a8dae35-eb02-45a2-80ae-a704902f26e0', 'endometrio', NULL, '2019-10-21', '2019-10-21', 'Metropatía hemorrágica', 'Legrado Diagnóstico donde se observa hipperplasia endometrial de bajo grado'),
('003d1ad3-c369-4833-91dc-2422d49da701', '5890', '7de45fdd-ac06-4b68-9530-6d599328a7ad', 'Histerectomia y ganglios', NULL, '2019-10-21', '2019-10-21', 'Neoplasia de cérvix', 'Histerectomía total con doble anexectomía donde se observa Carcinoma Epidermoide bien diferenciado infiltrante de cuello uterino, Endometritis crónica agudizada. Cadena ganglionar derecha con 2 ganglios no metastásicos e izquierda con metaplasia adiposa'),
('23c9749b-6d40-455e-8b84-b01c8896c62c', '5899', 'f851650e-bdd3-47fd-8c52-6bcdb87cd6d9', 'endometrio', NULL, '2019-10-21', '2019-10-21', 'Embarazo molar', 'Endometrio proliferativo.No mola hidatiforme'),
('1fb35474-f397-4790-b38b-431e5a939b4d', '5849', '39928f0d-38c8-4ce7-b7cf-88290503b342', 'Mucosa anal', NULL, '2019-10-21', '2019-10-21', 'Sangramiento digestivo bajo', 'Se observa infiltrado linfocítico y celulas plamáticas interglandulares'),
('f9aa6464-22cf-45d1-b05c-a28bb1b9b719', '5850', '464034b3-7dd4-44e0-8161-cfd6e2650eab', 'Mucosa de colon', NULL, '2019-10-21', '2019-10-21', 'Prolapso mucohemorroidal', 'Várices hemorroidales'),
('53580920-5c9b-418a-ad57-0b8e990ddfb1', '5851', 'f473399d-add8-437d-ab1f-54e491cc8d2c', 'Porción de lesión', NULL, '2019-10-21', '2019-10-21', 'T de recto', 'Adenocarcinoma bien diferenciado'),
('03202ad8-c3d6-4f84-8fb2-b2eacb2bf560', '5852', '0357093f-9ac8-4619-8348-e8a12be7cfc6', 'mucosa anal', NULL, '2019-10-21', '2019-10-21', 'Adenocarcinoma de recto', 'Se observa denso infiltrado inflamatorio linfocitario que bordea las glándulas de la mucosa del recto. No se observa tumor'),
('3fdde7e6-2303-45e0-aab6-146f98f94a58', '5853', '21d72bea-686c-4834-8e7b-bb7438409910', 'hemorroides', NULL, '2019-10-21', '2019-10-21', 'Hemorroides', 'Várices hemorroidales'),
('cb44efd5-ac35-4f11-b39a-c652229cc2c6', '5854', '649574c4-3843-4fc8-a44c-f666c33ff71e', 'mucosa anal', NULL, '2019-10-21', '2019-10-21', 'Fístula anal', 'Trayecto fistuloso con marcada inflamación aguda y crónica'),
('6835cc4f-1246-4b3b-89e5-74f0bd41c968', '5800', '4475ce8a-0864-4e01-b73d-92c01a937ba7', 'Piel', NULL, '2019-10-21', '2019-10-21', 'Carcinoma basal de pabellon auricular Carcinoma basal de region supraclavicular', '1-Carcinoma basal de pabellon auricular completamente resecado                  2-Carcinoma intraepitelial completamente resecado'),
('4eab32b7-a23d-4c0f-b01b-5df3d38eb4d6', '5855', '07c1c5ea-c8ef-41da-b4ff-22e91d023fa6', 'Mucosa de Colon', NULL, '2019-10-21', '2019-10-21', 'Prolapso Mucohemorroidal', 'Varices Hemorroidales'),
('1b399517-cdc7-440f-972c-28b2b3f251eb', '5907', '0db6c578-b63a-4e3d-a7b5-784dcd8fa584', 'Vesicula Biliar', NULL, '2019-10-21', '2019-10-21', 'Colesistititis aguda y T hepatica', 'Colicestectomia donde se observa un Adenocarcinoma moderadamente diferenciado con infiltracion Hepatica'),
('04624966-3728-4540-a8f5-c2f6ac79df7f', '5910', '4647c499-3039-4a3a-b1e1-0d34d80c1d59', 'Vesicula Biliar', NULL, '2019-10-21', '2019-10-21', 'Colecistitis Aguda', 'Colecistitis Aguda Litiasica'),
('fcd0ff55-90c1-49f4-8b8d-7392e97bc5d8', '5932', '63f9c5a9-bce7-44c6-bc0a-cc9761765007', 'Vesicula Biliar', NULL, '2019-10-21', '2019-10-21', 'Colangitis Aguda Supurada', 'Vesicula biliar con inflamacion aguda y cronica asi como vasos sanguineos dilatados'),
('001d858e-15f0-45a3-9861-5fc8b8878005', '5934', '30e7d74d-905f-4303-8c77-7bc83cb6cec6', 'Ambas trompas y Ovario Derecho', NULL, '2019-10-21', '2019-10-21', 'Peritonitis Generalizada', 'Ovario derecho donde se observa marcada inflamacion aguda y areas con abundante hemorragia  trompa con marcado infiltrado inflamatorio a predominio polimorfo nucleares'),
('d4287278-ab6e-434c-a2b0-79317b6c8b31', '5935', '175c94d4-3dc0-47d7-94c8-e9ba95e8d2c7', 'Utero', NULL, '2019-10-21', '2019-10-21', 'Proceso InflamatorioGinecologico', 'Histerectomia total sin anixectomia cuello con marcado infiltrado inflamatorio aguda y cronico correspondiente a cervicitis cronica metaplasia escamos y quiste de naboth. Cuerpo con endometrio secretor'),
('e1793d12-fa5b-4ff2-a931-684471659ea4', '6203', '6ac9ead6-4049-48a1-a1d0-640bc0dfbecc', 'Biopsia por Ponche', NULL, '2019-10-22', '2019-10-22', 'Ectopia Anarquica', 'Biopsia por ponche donde se observa un area con Carcinoma in Situ con extencion glandular.'),
('886e09bc-aa2c-4c41-9fc7-842fc6eece7b', '6182', '5cbe172f-52d3-4bf3-bbf1-e7fb952867e9', 'Piel', NULL, '2019-10-21', '2019-10-21', 'Carcinoma basal de ápex nasal', 'Se observa melanocarcinoma pigmentado ulcerado completamente resecado con escaso margen de profundidad que infiltra hasta dermis reticular,índice de Breslow en 0,1cm.Tipo histológico fusocelular, formando nidos con infiltración a vasos sanguíneos.'),
('f0fd8b09-e821-4ef0-a82a-0cabd269a8ca', '5807', '3f85ba01-1b33-4c05-912e-8b323bed21b0', 'Piel', NULL, '2019-10-14', '2019-10-14', 'Queratocantoma de brazo derecho', 'Biopsia de piel donde se observa Carcinoma Intraepitelial completamente resecado'),
('4028eb64-ec15-484c-af9a-e3f41a7fe926', '5591', '5a3a8a08-8183-4537-ac78-095ab93e7151', 'Recto-Sigmiode, ovario', NULL, '2019-10-25', '2019-10-25', 'Neo de recto', 'Se recibe pieza quirúrgica fracmentada en dos, la de menor tamaño 6,5x4 cm de diámetro, donde se observa un adenocarcinoma bien diferenciado que infiltra la submucosa, completamente resecado. El fragmento de mayor tamaño  8x3,5 cm: glándulas mucosas con i'),
('a4e495f2-b34a-4aae-881a-c5f6f6d48b40', '6152', 'c223c305-f9d6-4de5-96ef-903d1b3ab9d1', 'Piel', NULL, '2019-10-24', '2019-10-24', 'Tiña pedis y/o Psoriasis Plantar', 'Segmento de piel con hiperqueratosis y presencia de polimorfonucleares en la capa córnea, acantosis epitelial y ligero infiltrado inflamatorio crónico de la dermis superior. No lesiones histológicas de Psoriasis.'),
('ffd5a0e5-67bd-4221-a79f-d9fcd6e3fce9', '6162', '4a362885-b477-419b-b19b-979d9bce80b0', 'Piel', NULL, '2019-10-28', '2019-10-28', 'Granuloma piógeno de la piel del MSI. Nevus modificado', 'Granuloma piógeno completamente resecado'),
('5fc6af39-ea83-4c28-a7f2-d30303f64d06', '6369', '867b97f7-b458-44d2-8dcd-ea27b241f048', 'CxA', NULL, '2019-10-28', '2019-10-28', 'LIEBG', 'CxA donde se observa NIC I (Displasia Ligera) LIEBG, Cervicitis crónica. Bordes libres.'),
('1fc390b8-8231-44cd-b877-f952403edff6', '6370', '95494c0e-ef90-437a-aaf3-2d4880fbc829', 'BxA y BxP', NULL, '2019-10-28', '2019-10-28', 'BxA NICI                                                   BxP sin ID', 'BxA donde se observa epitelio exocervical. BxP donde se observa NIC I, (Displasia ligera), LIEBG y cervicitis crónica marcada.'),
('938ce76d-a88b-4c5c-9219-96f0e72bbd52', '6374', 'fca9cd94-0fd8-47d2-beac-3dd4d64daeff', 'B x P', NULL, '2019-10-28', '2019-10-28', 'NIC I', 'BxP dende se observa NIC I (Displasia ligera) LIEBG, Cervicitis crónica.'),
('605c6f86-ac51-430b-97d7-8f4471198a86', '6372', '3eeb3a88-eb6b-4858-a545-aa42cfb8a839', 'Vulva', NULL, '2019-10-20', '2019-10-20', 'Lesión de la vulva', 'Biopsia donde se observa epitelio escamoso con hiperqueratosis y ligera degeneración del colágeno subepitelial.'),
('5cb6ed84-94f2-4dc5-94bd-3aff78498a7f', '5927', '7b87e45a-e816-4ee2-8067-b59da2526c48', 'Piel', NULL, '2019-10-20', '2019-10-20', 'M:1 Carcinoma Basal de la piel de la mejilla                                                              M:2 Carcinoma basal de la piel del labio superior', 'Muestra 1: Carcinoma basal completamente resecado.                          Muestra 2: Queratosis completamente resacada.'),
('715f8d1c-9308-4663-86b0-b7d4f9a2cf0e', '5944', '644d560f-0256-4dfb-a738-b178f8effdb8', 'Piel', NULL, '2019-10-25', '2019-10-25', 'Carcinoma basal del pabellón auricular derecho', 'Queratosis con marcada inflamación crónica, completamente resecada.'),
('4708a3a9-a2ce-418c-ad9a-89682c24fb22', '6136', '7f85cc90-f6bc-45b3-82a4-bacf430d75a7', 'TPB', NULL, '2019-10-24', '2019-10-24', 'Biopsia anterior con Liposarcoma mixoide del muslo izquierdo', 'Muestra 1: Pieza quirúrgica con diagnóstico de un Liposarcoma mixoide del muslo izquierdo en Las Tunas, enviada para evaluar necrosis tumoral,  No se observa necrosis. Muestra 2: Bordes de sección quirúrgica no tumorales'),
('753731df-c6a7-4934-8739-278deae8d2f8', '6088', 'da793574-c910-475b-9532-894bc87dfcac', 'piel', NULL, '2019-10-24', '2019-10-24', 'nan', 'Fibroma con escasas áreas de hemorragia'),
('3abed816-c91b-4e62-ace0-763daa580c6f', '6086', '0145060f-1261-46d8-80a8-f2728dd73d74', 'piel', NULL, '2019-10-24', '2019-10-24', 'Carcinoma basal nodular', 'Carcinoma basal completamente resecado'),
('d31ae53e-8456-43a8-884b-011dd5f8d8ee', '6085', 'fbc5e5b8-5261-48a9-9076-4c695adbbf50', 'piel', NULL, '2019-09-24', '2019-09-24', 'Carcinoma basal ulcerativo', 'Carcinoma basal completamente resecado'),
('dab37bbe-d7a9-4e79-bc3a-ee5c2f2a0b74', '6087', 'ee35d41b-e1c0-41ae-931a-cb4d319fe62e', 'piel', NULL, '2019-10-24', '2019-10-24', 'Carcinoma basal pigmentado', 'Carcinoma basal completamente resecado'),
('15662042-7ebe-41ee-a555-a71178e114e7', '5919', '3fefdd2c-7309-41a3-a385-ee095cd8aec4', 'piel', NULL, '2019-09-24', '2019-09-24', 'Nevus verrugoso', 'Nevus pigmentado intradérmico completamene resecado'),
('370c746a-3829-46f6-9421-c6c786ea8490', '5982', '6c180484-a1db-413d-9792-635bb721e798', 'mucosa', NULL, '2019-10-24', '2019-10-24', 'T de canal anal', 'Biopsia de canal anal donde se observa biopsia de tejido linfoide y displasia severa del epitelio escamoso, se sugiere nueva toma de biopsia.'),
('379b397a-cd19-40d0-8b24-62e5e6267ded', '5913', '55a74992-b9cf-493e-b010-4d5b0c2ef216', 'Legrado diagnostico', NULL, '2019-10-24', '2019-10-24', 'Metropatía hemorrágica', 'Endometrio proliferativo.'),
('5a06a62b-d621-4ecb-86b2-3a9de7109eac', '6753', '365d15ad-71fc-4833-ab70-73fb56ce5434', 'apéndice', NULL, NULL, NULL, 'Apendicitis aguda flegmonosa', 'Apendicitis aguda supurada'),
('1d9ebb5a-c0f3-458e-958e-76aea6652282', '6751', '4e2760e9-68ea-494e-92b7-552e3eadc227', 'Apéndice', NULL, NULL, NULL, 'nan', 'Apendicitis aguda flegmonosa'),
('0da695d5-07c9-4ff0-998e-fbabbb23df68', '6742', '0e50122c-ae17-4dd3-8cac-1037a87af26b', 'Apéndice', NULL, NULL, NULL, 'nan', 'Apendicits aguda supurada'),
('7a711070-2526-474d-bffa-a7437fdd4af4', '6735', '2fd0c6ca-0109-48a6-be66-05947557449c', 'apéndice', NULL, NULL, NULL, 'nan', 'Apendicits aguda catarral'),
('dd17e0d2-267b-472f-8c44-c4cbf9153852', '6151', 'c076f208-efa5-49b9-bbdd-e7a64dd4636f', 'piel', NULL, '2019-10-24', '2019-10-24', 'Carcinoma basal', 'Carcinoma epidermoide bien diferenciado completamente resecado'),
('4e1d9ddd-0e22-4fda-b849-4ea095288a2f', '6153', '83a2ccc9-ecfb-4744-b00b-b947f3d024bb', 'piel', NULL, '2019-10-24', '2019-10-24', 'nan', 'Segmento de piel con marcada hiperqueratosis y acantosis epitelial'),
('c988b7fc-4a9b-45bf-a473-1e39d46bb467', '6137', '5c0b5f2b-0ddb-40e3-a007-5bd4a146138d', 'Útero y ambos anejos', NULL, '2019-10-25', '2019-10-25', 'Operada de Neoplasia de mama, Antecedentes de NIC I', 'Histerectomía total con doble anixectomía donde se observa Cervicitis crónica, Metaplasia escamosa, Quistes de Naboth, Fibroleiomioma intramural, Cuerpo amarillo hemorrágico y Cuerpo albicans.'),
('de602d69-9ec6-4ce5-b077-8a39b4d75a6c', '6354', '99d303cb-7d66-4e81-a443-6bb33c93f19b', 'LD', NULL, '2019-10-25', '2019-10-25', 'DHC', 'Legrado de canal donde se observan glándulas endocervicales fragmentadas, sangre y fibrina'),
('9c1e4d77-7d1e-41ea-96dc-739b12deb206', '6361', '1a14419e-75c3-41b6-8b6d-011064b34706', 'CxA', NULL, '2019-10-25', '2019-10-25', 'LIEAG', 'CxA donde se observa LIEAG, NIC III (Displasia Severa), Bordes libres.'),
('4c67b261-7bfb-488a-9dbf-2a1ba3042cd1', '6368', 'c74cc78c-1396-466d-bf24-d2cb4eacd6b5', 'BxP', NULL, '2019-10-25', '2019-10-25', 'nan', 'Biopsia por ponche del cuello uterino donde se observa displasia ligera y endocervicitis crónica.'),
('eee3d318-4fc9-44bd-ad30-629ffb5befd6', '6371', '1c9af52a-b1f0-49cd-8928-848928e751c5', 'CxA', NULL, '2019-10-25', '2019-10-25', 'NIC II', 'CxA donde se observa NIC II (Displasia moderada), lesión de alto grado, bordes libres.'),
('64154f84-4776-4abc-b7ac-f1af68617a38', '6283', 'd57da2a3-2596-425e-a012-94fb58ea04c3', 'Mucosa del colon', NULL, '2019-10-28', '2019-10-28', 'Colitis inespecífica', 'Mucosa del colon con abundante inflamación aguda y crónica'),
('f1ed0bb2-cd27-4f9d-b96c-caf5b456a04c', '6473', '3e23f4c7-bc02-454a-945d-f074a4a049f4', 'Piel', NULL, '2019-10-28', '2019-10-28', 'Lesión de piel del tórax', 'Carcinoma epidermoide…….completamente resecado, con marcada inflamación crónica.'),
('4893c6c1-9c8d-45a0-8ec0-f9599c13320e', '6155', 'a50a5d19-b8ed-42e8-813a-026b0f0af9b9', 'piel', NULL, '2019-10-24', '2019-10-24', 'Carcinoma basal', 'Carcinoma basal completamente resecado'),
('35e2a44c-d4cb-415b-9172-f8fd440fda28', '6156', 'e57c2e66-2750-4976-b7d6-bdf1b0cc9f65', 'piel', NULL, '2019-10-24', '2019-10-24', 'Carcinoma basal', 'Carcinoma basal completamente resecado'),
('39e356de-87d7-42d9-babe-9d38d74c46d4', '6176', '11111786-40ed-4e08-afb9-28a53637719f', 'piel', NULL, '2019-10-24', '2019-10-24', 'Carcinoma basal extenso', 'Carcinoma basal completamente resecado'),
('4226479a-504d-4089-9a2a-4df83f73df0c', '6242', '047ef0fd-e4b3-49e0-8a25-10bfe3c57619', 'piel', NULL, '2019-10-24', '2019-10-24', 'Carcinoma basal', 'Quiste de inclusión epidérmica completamente resecado'),
('322ca452-0653-452a-8cde-e4c633b4451d', '6269', '4908ad9a-7205-48f8-8297-58836a333151', 'legrado diagnóstico', NULL, '2019-10-24', '2019-10-24', 'Pólipo endometrial', 'Hiperplasia endometrial de bajo grado(quística)'),
('5014f6d8-7c6f-47eb-935a-efadb1fdd671', '6422', 'efd28e85-35e7-4f79-aaf5-d2ef466bcaf1', 'cilindros prostáticos', NULL, '2019-10-23', '2019-10-23', 'Adenocarcinoma de próstata', 'Predominan componente estromal en cilindros de lóbulo Derecho, muy pocas glándulas con hiperplasia intraductal con neoplasia intraepitelial severa(PIN3).Se observa adenocarcinoma ductal papilar en 60% de muestra de lóbulo izquierdo.Grupo5 Dado por Gleason'),
('a4b75885-fd89-474b-8ba8-4024aa56f307', '6382', '88ce17ba-0217-4209-998b-22abbbbaa9a7', 'mucosa anal', NULL, '2019-10-24', '2019-10-24', 'nan', 'Biopsia donde se observa un carcinoma con inflamación linfoide'),
('2db443d6-ff61-4c9f-8a5e-9ec47e5281c2', '5962', '85007cf3-d009-4432-b1c4-9e4ab40a23f9', 'mama derecha', NULL, '2019-10-18', '2019-10-18', 'nan', 'Mastectomía radical modificada derecha por carcinoma papilar infiltrante(18-B-8669).Desmoplasia y alteración fibroquística con hiperplasia ductal en grasa de prolongación axilar se encuentra un ganglio no metastásico a pesar de examinar minuciosamente la'),
('38f60a2e-a257-48ff-9813-3d60333d59b8', '6364', '826980a4-94eb-4373-bbde-59e542f146c3', 'Mucosa Gástrica', NULL, '2019-10-28', '2019-10-28', 'Pólipo de estómago', 'Biopsia gástrica fragmática donde no se observa pólipo'),
('76a4accd-13cb-44fc-a470-7f836c434f7b', '6373', '89fc6a76-bbc8-48e3-9656-bd87937d237a', 'Cono Diagnóstico', NULL, '2019-10-28', '2019-10-28', 'NIC II', 'CxA contituido por exocervis con NIC II bordes libres'),
('3c550a66-7b25-4009-a914-a766fc623d92', '6104', 'bc6feed3-c202-450f-a5f0-bc26a663bcec', 'Nódulo mamario', NULL, '2019-10-22', '2019-10-22', 'Ectasia ductal', 'Biopsia excisional de tejido mamario con papiloma intraquístico, inflamación crónica periductal, alteración fibroquística. En margen externo se observa hiperplasia intraductal.'),
('2f9d391e-22f7-4ac9-a313-d72cb87cfdff', '6271', '0dac145f-a321-432b-b72b-3770a1be6120', 'Nodulectomía mamaria', NULL, '2019-10-22', '2019-10-22', 'nan', 'Fibroadenoma'),
('4a18639e-8424-4917-b90c-7601da055dea', '6316', 'ba5406e0-91ef-4776-acc0-e04df85efd02', 'Mama y nivel I-II', NULL, '2019-10-23', '2019-10-23', 'nan', 'Nodulectomía mamaria izquierda.Papiloma intraquístico en áreas de alteración fibroquística con adenosis microglandular.'),
('f988d088-b57c-40f2-92cc-04c06a837512', '6334', 'b9480e76-1a3b-4bf8-934c-862147089662', 'Nodulectomía mamaria', NULL, '2019-10-23', '2019-10-23', 'nan', 'Ginecomastia'),
('4e2781f8-3be7-4d3d-b806-69022bd37430', '6333', '8ba17fc7-1e31-4c0b-a6a2-03f6c632b06e', 'Adenopatías', NULL, '2019-10-23', '2019-10-23', 'T de axila izquierda', 'Muestra de biopsia constituida solamente por tejido fibrógeno. No se observa tejido mamario ni ganglios linfáticos'),
('5f28a4e4-3c78-4e7d-aa61-45b3d442c4d2', '6324', 'd52eaf0b-49aa-42c7-bdb9-84753684db6f', 'Nodulectomía mamaria', NULL, '2019-10-23', '2019-10-23', 'nan', 'Biopsia contituida por tejido mamario con alteración fibroquística-lipoma.'),
('9c462a83-2934-46f3-81e5-7eb25d6698ff', '6389', 'da81cba5-9a47-4405-bde3-12d69f957204', 'Mama Izquierda y nivel I-II', NULL, '2019-10-23', '2019-10-23', 'nan', 'Mastectomía radical modificada Izquierda que llevó tratamiento neoadyuvante por BAAF 134(positiva), se observa conductos aislados con células ductales atípicas, 1 ganglio linfático positivo con respuesta tumoral parcial'),
('7f576008-ab22-40fb-a5b3-d6fd3ce3a91d', '6335', '1f3b2648-259e-4a80-acc0-6a088abcbf77', 'Nodulectomía mamaria', NULL, '2019-10-23', '2019-10-23', 'Ectasia ductal', 'Alteración fibroquística.'),
('df77b11f-a8d0-4da1-9fee-90633593ac41', '6336', '150fd6ad-1d97-4c81-a8c5-c0c3fbf37113', 'Nodulectomía mamaria', NULL, '2019-10-23', '2019-10-23', 'nan', ' Papiloma intraquístico en un área extensa de alteración fibroquística con papilomatosis intraductal. Metaplasia apocrina.Hiperplasia ductal, adenosis microglandular focal y abundantes microcalcificaciones.Borde superior con hiperplasia ductal.'),
('54cbf655-106f-4c56-8f78-1fd03906d8e8', '6259', '40e557a5-b748-44ea-ab67-554c4a15ffcd', 'útero', NULL, '2019-10-23', '2019-10-23', 'Fibroma uterino', 'Histerectomía total con doble anexectomía.Cervicitis crónica.Endometrio secretor tardío.Fibroleiomioma uterino intramural .Quiste folicular'),
('cf0c79c4-1e1b-4983-b9d3-ee682936b837', '6390', 'e088a9c6-84ef-424d-bd0b-9b769d414d24', 'Mamila derecha', NULL, '2019-10-25', '2019-10-25', 'Nodulo de mama derecha', 'Nodulo de mamila derercha Quiste de imclucion intraepidermico marcado infiltrado inflamatorio agudo y cronico en uno de sus estremos. Adenoma de glandulas cebaceas'),
('0a1f4147-0c56-4464-969f-65ae645c4cce', '5891', '6974a5c8-41e2-479d-9c63-80c01343c3d9', 'nan', NULL, '2019-10-25', '2019-10-25', 'nan', ' 2 piezas, en la primera   se observa un adenocarcinoma bien diferenciado que infiltra la mucosa y se encuentra completamente resecado, el otro  glandulas mucosas con inflamacion crónica ,no tumor, tejido vascularizado con cavidades quísticas'),
('aeb43fc8-a6d1-4a2b-a045-9c03177fb63c', '5928', 'd8bdbf55-4c1c-464f-a627-baf0630aa3c6', 'nan', NULL, NULL, NULL, 'nan', 'biopsia de piel con marcada hiperqueratosis y tapones córneos e inflamación  crónica subepitelial completamente resecada 2 queratoacantoma completamente resecado'),
('cae2b4a0-7fb6-44e2-b509-dadd0f12c3c9', '6187', 'dd1190c3-5970-451c-8775-cb78259d265d', 'nan', NULL, NULL, NULL, 'nan', 'Muestra1: Quiste de inclusión epidérmica completamente resecado.  Muestra 2: Queratosis seborreica completamente resecada'),
('f92c0692-b58c-4cfa-8f9e-1fe8fcd2838d', '6215', '570c4124-dded-4248-b08d-bbb217ba467b', 'nan', NULL, NULL, NULL, 'nan', 'Carcinoma basal completamente resecado'),
('f9763b87-0457-4ee9-a17a-d28d1b263d5a', '6216', 'd8abc800-fc06-476e-941f-7c931856c77f', 'nan', NULL, NULL, NULL, 'nan', 'Carcinoma Basal completamente resecado'),
('b2c3e6d1-a037-492a-9e18-8d605371819d', '6217', '5b917091-ed1d-40c5-b0b0-9c5efd13e459', 'nan', NULL, NULL, NULL, 'nan', 'Carcinoma basal completamente resecado'),
('d776e3ac-bc18-45ed-b490-3831f1d3b08e', '6221', '4dc80361-e524-4e01-a6e4-498a3bbccdb1', 'nan', NULL, NULL, NULL, 'nan', 'Carcinoma basal completamente resecado'),
('5edb3a43-96f9-47f9-922f-20be111a2e1c', '6224', 'f903150c-0b7c-466c-b6a4-37305d7de70a', 'nan', NULL, NULL, NULL, 'nan', 'Bocio multinodular con áreas de hiperplasia del epitelio multinodular y formación de microquistes'),
('556c5c3c-f9de-455d-ae6c-b1295af6a9c3', '6233', 'd3f17781-8708-46c8-a71e-86d007f38062', 'nan', NULL, NULL, NULL, 'nan', 'Endometrio secretor tardío'),
('5d0fd628-cbf4-4b78-9ed0-bff18745c570', '6234', '2be7bb03-6d04-4a3e-a52a-f454fa72bb1f', 'nan', NULL, NULL, NULL, 'nan', 'Materialo constituido por sangre y glándulas endocervicales. Pólipo endocervical'),
('7e348a1c-0ec5-4200-a013-1f4f395eb8bb', '6235', 'f09ccd74-88d2-4a17-b57b-5314ce72ef4b', 'nan', NULL, NULL, NULL, 'nan', 'Hiperplasia endometrial de bajo grado (quística)'),
('22a4599f-d4b2-4473-aefd-b534f649fa71', '6237', '2b76d48d-b628-49dc-bc4c-b704b6f1d995', 'nan', NULL, NULL, NULL, 'nan', 'Endometrio proliferativo'),
('d445c931-8730-44fb-910b-9b18de095fba', '6238', '89a3abbf-f96c-4a9c-8224-583dd86854b5', 'nan', NULL, NULL, NULL, 'nan', 'Endometrio proliferativo'),
('f33a989b-ff8f-4589-9bdb-21a2e41352e8', '6279', 'bd39029a-c392-41d9-a67d-712e01b24e48', 'Biopsia por ponche', NULL, '2019-10-23', '2019-10-23', 'Lesión intraepitelial de bajo grado', 'Biopsia por ponche con áreas de NIC I (displasia ligera) lesión de bajo grado.'),
('af1e5b86-2454-4019-9f0e-0d79afc2be75', '6394', 'c106e59b-0269-4196-8a2c-b4de83205109', 'Histerectomía con anexectomía derecha', NULL, '2019-10-23', '2019-10-23', 'NIC II y fibroma uterino', 'Histerectomía total con doble anexectomía. Cervivitis crónica. Fibroleiomioma uterino subseroso e intramural.Endometrio secretor tardío.Quiste folicular de ovario.'),
('145a0997-dccc-4719-8820-7c1b53e3f97e', '5989', '4ea31b9c-ed08-4a85-91ea-b61611f615d0', 'mucosa labial', NULL, '2019-10-23', '2019-10-23', 'Leucoplasia', 'Segmento de piel con hiperpigmentación de la capa basal ligera hiperqueratosis e hialinización del colágeno'),
('43d8c080-03a3-4fed-920b-8861143d5536', '6280', 'b35cbfde-03d0-4e39-a603-6c0a597a1ae3', 'Cono por asa', NULL, '2019-10-23', '2019-10-23', 'nan', 'Cono por asa donde se observa abundante metaplasia escamosa endocervical y NIC I (displasia ligera).Lesión de bajo grado.Bordes libres.'),
('75e0b1f2-cde5-4f9e-8df8-26aa02a16992', '6308', 'afff462a-006e-4d16-87d0-9d2acb04713f', 'Histerectomía total con doble anexectomia', NULL, '2019-10-23', '2019-10-23', 'Fibroma uterino', 'Histerectomía total con doble anexectomía.Cervicitis crónica.Endometrio secretor tardío.Quiste folicular'),
('d07da82d-5ac6-4ddd-af78-15e31b5940d2', '6309', '7f4fbfc3-8c1e-4e9c-93b6-0b690a084cee', 'Histerectomía total con doble anexectomía', NULL, '2019-10-23', '2019-10-23', 'Quiste de ovario simple Fibroma uterino', 'Histerectomía total con doble anexectomía.Cervicitis crónica.Fibroleiomioma uterino subseroso e intramural.Quiste folicular de ovario'),
('cb981fe6-321c-403d-ba1e-01312a4f8495', '6310', '32e78fb4-ea60-4541-aa37-2e915f5eca4a', 'Histerectomía total con doble anexectomía', NULL, '2019-10-23', '2019-10-23', 'Fibroma uterino', 'Histerectomía total con doble anexectomía.Cervicitis crónica.Fibroleiomioma uterino subseroso .Cuerpo albicans de ovario'),
('1dba74ad-aeac-43c5-a1b5-9fef68cbf17d', '6311', '284d7ea0-e81e-4ea3-be7e-82fec1f6ec92', 'Histerectomía total con doble anexectomía.', NULL, '2019-10-23', '2019-10-23', 'Fibroma uterino', 'Histerectomía total con doble anexectomía.Cervicitis crónica.Fibroleiomioma uterino subseroso e intramural.Endometrio secretor tardío.Cuerpo albicans de ovario'),
('c63f5897-97e4-4cd8-a6c3-dfcaec3661cf', '6376', '4a014166-06bd-4994-9c8e-880de2f87449', 'Esófago', NULL, '2019-10-28', '2019-10-28', 'Tumor de esófago', 'Carcinoma epidermoide bien diferenciado'),
('eda55f7f-942a-417c-9a4a-5f1fc8742838', '6541', 'f342afa3-0cfc-4bda-89c7-9e7b7dbf008f', 'Lesión del canal anal', NULL, '2019-10-28', '2019-10-28', 'adenocarcinoma canal anal', 'carcinoma epidermoide moderada diferenciado del canal anal'),
('fde4927b-c027-4309-bec5-5bca2bec04a0', '6673', '856db182-8f62-4da5-bd6e-423f5625c56a', 'Cono Diagnóstico', NULL, '2019-10-28', '2019-10-28', 'Lesion PDT TDL Displacia Ligera', 'NIC I Lesion de bajo grado y Metaplacia Bordes Libres Metaplacia Ligera'),
('04856f40-7061-4a42-9f1c-9f8a15af5353', '6424', 'f83efbb4-8b13-4184-ad05-741b84556044', 'Vesícula', NULL, '2019-10-28', '2019-10-28', 'Colecistitis aguda litiásica', 'Cilecistitis Aguda'),
('527adac2-0de3-4447-acc5-3baa4551bf45', '6317', '9aecf405-e302-4763-b4aa-197aa444b5af', 'Recto', NULL, '2019-10-28', '2019-10-28', 'Tumor de recto', 'Adenocarcinoma bien diferenciado infiltra, la capa muscular bordes libres, no se resiven daños linfáticos'),
('fc45d27a-8093-49cb-afe6-22e978ee6857', '6307', '3c66cb94-f289-4550-a24f-01c5a5f9d373', 'Intestino Grueso', NULL, '2019-10-28', '2019-10-28', 'Tumor del Recto', 'Adenocarcinoma bien diferenciado infiltra, la capa muscular tomandovasos sanguineos y vasos linfáticos, Bordes proximal y distal libre de tumor, Ganglios linfáticos no metastásicos'),
('8dceb5bc-9d5a-433e-baae-a3553dec7b76', '6353', 'adb0afcf-fdb5-4ada-9384-1f6d0a080c7c', 'Vesícula Biliar', NULL, '2019-10-28', '2019-10-28', 'Colecistitis Aguda', 'Colecistitis Aguda Supurada'),
('ad64a5ce-3e98-4034-856d-11b039cb6e1b', '6239', '3e127f2e-f628-4241-9ad4-16e080f599c4', 'nan', NULL, NULL, NULL, 'nan', 'Endometrio proliferativo'),
('b62e29c9-60c0-4a96-bcaa-db4cb82344c2', '6240', 'a5efa4d7-33ba-45ec-b335-c7bcc7353540', 'nan', NULL, NULL, NULL, 'nan', 'Pólipo endometrial'),
('08ac3601-7ce7-40ad-91cf-24c392c8e3bf', '6270', 'ab3b97b9-37d2-42bb-a2c2-39c9d72abaa5', 'nan', NULL, NULL, NULL, 'nan', 'Nodulectomía mamaria derecha. Biopsia constituida por tejido fibrograso mayormente y muy escasos conductos mamarios rodeados de inflamación crónica'),
('cb158c8d-c540-46db-bcf7-4deb3d17269f', '6285', '2c442775-7901-4cbf-9ef8-656213f7cc4a', 'nan', NULL, NULL, NULL, 'nan', 'Hiperplasia endometrial de bajo grado'),
('c17aa375-03ab-41b2-a649-a10f13eaf907', '6287', '8ead9860-1c86-4e85-8463-5d360cb9971f', 'nan', NULL, NULL, NULL, 'nan', 'Endometrio secretor femenino'),
('de06189e-35a7-4e54-aff2-88f1693e6e3e', '6332', 'be78f18b-dabd-4ee8-8dc0-c778ac26af26', 'nan', NULL, NULL, NULL, 'nan', 'Histerectomía total con doble anisectomía, quistes de Nabot, fibroleiomioma uterino intramural, quiste folicular de ovario, cuerpo albicans y cuerpo amarillo'),
('4aac4a10-3832-4824-bd88-b82c142a8771', '6343', 'd288f22c-ed6d-4c2a-a871-37381c953574', 'nan', NULL, NULL, NULL, 'nan', 'Histerectomía total con doble anisectomía. Fibroleiomioma uterino submucoso. Cuerpo amarillo y albicans de ovario'),
('8a338658-3a74-492e-8d37-ed12ff38f26a', '6348', '9d698f96-9897-44c2-9f66-02d874e40c2f', 'nan', NULL, NULL, NULL, 'nan', 'Quiste simple de ovario'),
('ca903986-fa93-49a2-bfb6-817f202e00c5', '6349', '2af2144d-f8a2-4b63-a908-a4af8999d35f', 'nan', NULL, NULL, NULL, 'nan', 'Histerectomía total con doble anisectomía. Metaplasia escamosa. Cervicitis crónica. Endometrio secretor. Anejos sin alteraciones'),
('a364fefb-5168-48da-baa9-37cacd5ff924', '6359', 'c153f105-b5f0-49b1-91a7-580c71f4f00b', 'nan', NULL, NULL, NULL, 'nan', 'Biopsia por ponche donde se observa NIC 1, displasia ligera , lesión intraepitelial de bajo grado, cervicitis crónica'),
('1d4f064b-7fed-4a35-b659-bce6b6be8622', '6315', '86efe837-98a5-4fb1-90af-4ddd3451bf92', 'nan', NULL, NULL, NULL, 'nan', 'Nodulectomía mamaria izquierdea. Marcado infiltrado inflamatorio agudo y crónico. Hiperplasia ductal. Inflamación granulomatosa.'),
('67e94aa7-0ac1-4065-920c-97793d0bdf71', '6227', '33fb1d87-1ad3-4ba3-a96e-eaddbbbc5121', 'nan', NULL, NULL, NULL, 'nan', 'Histerectomía total con doble anisectomía. Quistes de Nabot. Fibroleiomioma intramural. Cuerpo albicans y cuerpo amarillo de ovario'),
('8d21f55c-ea24-46df-9375-7a2eb8c2effa', '6328', 'b5276a03-c03f-4631-86bf-90af53ff2e6f', 'nan', NULL, NULL, NULL, 'nan', 'Histerectomía total con doble anisectomía. Metaplasia escamosa. Quistes de Nabot. Fibroleiomioma uterino intramural. Cuerpo amarillo y albicans de ovario'),
('d0d8ecda-6447-4647-a869-260ec6564094', '6339', '7ef0a679-7aa9-4144-8eee-c11107547420', 'nan', NULL, NULL, NULL, 'nan', 'Histerectomía total con doble anisectomía. Cervicitis crónica. Metaplasia escamosa. Endometrio secretor. Quistes foliculares de ovario'),
('820cf14f-4c56-4d9c-97ff-91248ca32767', '6341', '714d741f-acb1-43a2-81ef-14cce4556fa6', 'nan', NULL, NULL, NULL, 'nan', 'Histerectomía total con doble anisectomía. Quistes de Nabot. Fibroleiomiomas uterinos subserosos y múltiples intramurales. Cuerpo amarillo hemorrágico de ovario'),
('9d77956b-88dd-4a7b-bce4-e72b75107608', '6130', '10ef1812-bf2c-4a78-80f9-55b0e65abbad', 'nan', NULL, NULL, NULL, 'nan', 'material constituido por sngre y glandulas endocervicales con inflamación crónica'),
('a7291f29-2d67-4f78-ae69-5420342378bb', '6319', '8e2de783-b3ac-4629-9017-ff814645f946', 'Histerectomía total con doble anexectomía', NULL, '2019-10-23', '2019-10-23', 'NIC II Y Fibroma uterino', 'Histerectomía total con doble anexectomía.Cervicitis crónica.Fibroleiomioma uterino  imtramural y DIU en cavidad endometrial.Cuerpo amarillo de ovario hemorrágico'),
('8852c22b-1abf-4049-b396-768485eae8ad', '6320', 'deb78b7b-2891-4b75-8a52-9e3a329f9f40', 'Histerectomía total con doble anexectomía.', NULL, '2019-10-23', '2019-10-23', 'Fibroma uterino', 'Histerectomía total con doble anexectomía.Cervicitis crónica.Fibroleiomioma uterino subseroso.Cuerpo albicans de ovario'),
('0be84212-2d16-44c9-9aa9-46a3d14d8564', '6321', 'c3e2bac8-a68d-4af3-a73a-f33b9d65137e', 'Histerectomía total con doble anexectomía.', NULL, '2019-10-23', '2019-10-23', 'Fibroma uterino', 'Histerectomía total con doble anexectomía.Cervicitis crónica.Fibroleiomioma uterino imtramural.Cuerpo amarillo de ovario');
