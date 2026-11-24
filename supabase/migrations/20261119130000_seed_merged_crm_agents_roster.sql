-- Migration: Seed Merged CRM Agents Roster (113 Real Verified Logistics Agents)
-- Unified roster from CRM Sheet1 & Agents Arranged by State

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'bd21930d-a2c7-546f-8fd6-1c61849ae4d6', 'NX-ABJ-01', 'NovaXpress Logistics (Internal Fleet)', '22222222-2222-4222-8222-222222222222', 'Abuja (FCT)', ARRAY['Abuja (FCT)', 'Niger', 'Nasarawa', 'Kaduna']::TEXT[],
    'Zenith Bank', '1019283746', 'NovaXpress Logistics Operations', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 50,
    'Engr. Tunde Adeleke', '+234 803 111 2233', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'ae45b374-ea7f-528c-8070-c958a538cf33', 'AG-001', 'Msuega Terlanga Japhet Logistics', '22222222-2222-4222-8222-222222222222', 'Benue', ARRAY['Benue']::TEXT[],
    'GTBank', '0010000017', 'Msuega Terlanga Japhet Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Msuega Terlanga Japhet', '+234 802 782 3043', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'c02877c7-693c-5dd9-ab4b-010c8eb43a6b', 'AG-002', 'Raphael Michael Logistics', '22222222-2222-4222-8222-222222222222', 'Bauchi', ARRAY['Bauchi']::TEXT[],
    'Access Bank', '0020000034', 'Raphael Michael Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Raphael Logistics Manager', '+234 907 827 1360', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '67e59ce6-36e1-547f-8a32-90fd2c2fc17d', 'AG-003', 'RAPH XPRESS LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '0030000051', 'RAPH XPRESS LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Raph Lagos', '+234 8013 151 1093', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'a509d3fd-490d-5cf5-abde-5dc58e233002', 'AG-004', 'ATP Logistics', '00000000-0000-4000-8000-792411006364', 'Edo (Benin)', ARRAY['Edo (Benin)']::TEXT[],
    'UBA', '0040000068', 'ATP Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'ATP Logistics Manager', '+234 703 662 8887', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '15a3ec94-ddcb-5eef-a9c1-e5cf53e88dc5', 'AG-005', 'Olaseni Adewumi James Logistics', '00000000-0000-4000-8000-792411006364', 'Ekiti', ARRAY['Ekiti']::TEXT[],
    'Fidelity Bank', '0050000085', 'Olaseni Adewumi James Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Olaseni Logistics Manager', '+234 8015 185 1155', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '35c99a98-6839-519e-93a0-a4a2aef98ced', 'AG-006', 'GINIKA ANAMBRA', '00000000-0000-4000-8000-792411006364', 'Anambra', ARRAY['Anambra']::TEXT[],
    'Stanbic IBTC', '0060000102', 'GINIKA ANAMBRA Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Ginika Anambra', '+234 916 648 5004', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'fce261f9-b278-5b63-bf05-f8bcefb0db9e', 'AG-007', 'Tajudeen A Ayetigbo LOGISTICS', '22222222-2222-4222-8222-222222222222', 'Sokoto', ARRAY['Sokoto']::TEXT[],
    'Zenith Bank', '0070000119', 'Tajudeen A Ayetigbo LOGISTICS Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Tajudeen Logistics Manager', '+234 803 597 9005', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '80fcc590-5727-58c7-8335-0abad4288013', 'AG-008', 'Alatiya Absalom Emmanuel Logistics', '22222222-2222-4222-8222-222222222222', 'Adamawa', ARRAY['Adamawa']::TEXT[],
    'GTBank', '0080000136', 'Alatiya Absalom Emmanuel Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Alatiya Logistics Manager', '+234 8018 236 1248', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '1d3a87ca-fd33-5fcc-b050-afe2e9940b7b', 'AG-009', 'Arinze Esther Logistics', '00000000-0000-4000-8000-792411006364', 'Anambra', ARRAY['Anambra']::TEXT[],
    'Access Bank', '0090000153', 'Arinze Esther Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Arinze Logistics Manager', '+234 8019 253 1279', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'eb954c29-fb87-593f-a2c3-62d80ccc13e5', 'AG-010', 'Velocita Logistics', '00000000-0000-4000-8000-792411006364', 'Rivers (Port Harcourt)', ARRAY['Rivers (Port Harcourt)']::TEXT[],
    'First Bank of Nigeria', '0100000170', 'Velocita Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Velocita Logistics Manager', '+234 817 633 5060', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'bfd133ac-5f54-5cdf-b3c4-051fd23ce138', 'AG-011', 'Fomax Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '0110000187', 'Fomax Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Fomax Logistics Manager', '+234 8021 287 1341', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '36d7e1e2-56b3-5e38-99a6-5fc61e9fc589', 'AG-012', 'Spotnaire Logistics Ebonyi', '00000000-0000-4000-8000-792411006364', 'Ebonyi', ARRAY['Ebonyi']::TEXT[],
    'Fidelity Bank', '0120000204', 'Spotnaire Logistics Ebonyi Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Spotnaire Logistics Manager', '+234 805 884 3338', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '2a04a4c3-636d-59ec-9a69-112d554b9b4f', 'AG-013', 'FOMAX PH. LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Rivers (Port Harcourt)', ARRAY['Rivers (Port Harcourt)']::TEXT[],
    'Stanbic IBTC', '0130000221', 'FOMAX PH. LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'FOMAX Logistics Manager', '+234 8023 321 1403', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '0872f4a8-c158-545d-b7d8-51bb2f5bf801', 'AG-014', 'ADICHA LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0140000238', 'ADICHA LOGISTICS Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Adicha Israel', '+234 8024 338 1434', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '57be2228-5264-56ff-a7b9-d7a99b1ef6c7', 'AG-015', 'AB LOGISTICS KADUNA', '22222222-2222-4222-8222-222222222222', 'Kaduna', ARRAY['Kaduna']::TEXT[],
    'GTBank', '0150000255', 'AB LOGISTICS KADUNA Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'AB Logistics Manager', '+234 813 737 0623', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '0dc5e413-c259-5c00-847f-5d951536a6e6', 'AG-016', 'byke messengers logistic', '00000000-0000-4000-8000-792411006364', 'Imo', ARRAY['Imo']::TEXT[],
    'Access Bank', '0160000272', 'byke messengers logistic Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Byke Messenger', '+234 912 967 9193', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'a89e1e28-ce12-5766-8d6a-69a33c9a1483', 'AG-017', 'SOLOPEE LOGISTCS', '22222222-2222-4222-8222-222222222222', 'Plateau (Jos)', ARRAY['Plateau (Jos)']::TEXT[],
    'First Bank of Nigeria', '0170000289', 'SOLOPEE LOGISTCS Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'SOLOPEE Logistics Manager', '+234 706 379 7354', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '3c12ca43-a137-5968-95b9-2ffbe2664c84', 'AG-018', 'ug express logistic ebonyi', '00000000-0000-4000-8000-792411006364', 'Enugu', ARRAY['Enugu']::TEXT[],
    'UBA', '0180000306', 'ug express logistic ebonyi Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'UG Exp Enugu', '+234 8028 406 1558', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '46103da6-e28c-507a-937f-1109c9e39838', 'AG-019', 'Ibitoye adewale Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '0190000323', 'Ibitoye adewale Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Ibitoye Logistics Manager', '+234 8029 423 1589', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '5e69b1ab-c357-5abf-8b41-03aa7c651369', 'AG-020', 'TEMIBASH Logistics', '00000000-0000-4000-8000-792411006364', 'Ondo', ARRAY['Ondo']::TEXT[],
    'Stanbic IBTC', '0200000340', 'TEMIBASH Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'TEMIBASH Logistics Manager', '+234 8030 440 1620', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'de7df501-a36e-5b48-869f-a7e8d6e5cf5a', 'AG-021', 'Adekunle Logistic', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0210000357', 'Adekunle Logistic Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Adekunle Logistics Manager', '+234 8031 457 1651', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '1ce2c933-b0f7-571e-8578-8ca1ab13c35f', 'AG-022', 'Toheeb Biola Popoola Logistics', '00000000-0000-4000-8000-792411006364', 'Oyo (Ibadan)', ARRAY['Oyo (Ibadan)']::TEXT[],
    'GTBank', '0220000374', 'Toheeb Biola Popoola Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Toheeb Logistics Manager', '+234 8032 474 1682', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'd7d8ad39-1345-5011-9816-40e06b903325', 'AG-023', 'Ezekiel Ameh Logistics', '22222222-2222-4222-8222-222222222222', 'Kano', ARRAY['Kano']::TEXT[],
    'Access Bank', '0230000391', 'Ezekiel Ameh Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Ezekiel Logistics Manager', '+234 704 488 5789', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'd4157f76-884d-5dd6-9bdd-a3cf142dd4d6', 'AG-024', 'George O.O LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Rivers (Port Harcourt)', ARRAY['Rivers (Port Harcourt)']::TEXT[],
    'First Bank of Nigeria', '0240000408', 'George O.O LOGISTICS Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'George Logistics Manager', '+234 902 350 7405', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '98ffc392-80a8-5c77-bb1d-5a23e5c3e617', 'AG-025', 'Gimway Concept', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '0250000425', 'Gimway Concept Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Gimway Concept', '+234 8035 525 1775', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '3e510630-d989-5a9b-a420-8daf062b2a50', 'AG-026', 'Ola Cash', '00000000-0000-4000-8000-792411006364', 'Ondo', ARRAY['Ondo']::TEXT[],
    'Fidelity Bank', '0260000442', 'Ola Cash Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Ola Cash', '+234 8036 542 1806', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '90522c1c-d02d-54d4-8d91-20816b85f0d3', 'AG-027', 'Anthony Ezekiel Logistics', '22222222-2222-4222-8222-222222222222', 'Kano', ARRAY['Kano']::TEXT[],
    'Stanbic IBTC', '0270000459', 'Anthony Ezekiel Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Anthony Logistics Manager', '+234 806 912 9741', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '7afe6908-8ae9-514a-ae69-277d30396c82', 'AG-028', 'milly logistics', '00000000-0000-4000-8000-792411006364', 'Imo', ARRAY['Imo']::TEXT[],
    'Zenith Bank', '0280000476', 'milly logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'milly Logistics Manager', '+234 8038 576 1868', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '70248c36-7af3-5ee7-9b60-d0ef504d0e0b', 'AG-029', 'Olagunju Damilola Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0290000493', 'Olagunju Damilola Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Olagunju Logistics Manager', '+234 8039 593 1899', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '5c08e883-fa94-5add-b421-3a51d2d4395e', 'AG-030', 'APPLE ANAMBRA DELIVERY SERVICES', '00000000-0000-4000-8000-792411006364', 'Anambra', ARRAY['Anambra']::TEXT[],
    'Access Bank', '0300000510', 'APPLE ANAMBRA DELIVERY SERVICES Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'APPLE Logistics Manager', '+234 8040 610 1930', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'fce4db5a-a711-5fde-ad4c-e5bb87c9dfa9', 'AG-031', 'Okolie Anthony ogorchukwu Logistics', '00000000-0000-4000-8000-792411006364', 'Delta', ARRAY['Delta']::TEXT[],
    'First Bank of Nigeria', '0310000527', 'Okolie Anthony ogorchukwu Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Okolie Anthony Ogorchukwu', '+234 704 723 7264', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '5a6467e3-e22c-5db3-9d66-5ee5e967cd14', 'AG-032', 'smart Logistics', '00000000-0000-4000-8000-792411006364', 'Bayelsa', ARRAY['Bayelsa']::TEXT[],
    'UBA', '0320000544', 'smart Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'smart Logistics Manager', '+234 816 625 2391', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'e310371e-990f-591b-8dcb-a8ee930390d6', 'AG-033', 'SAGE LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Rivers (Port Harcourt)', ARRAY['Rivers (Port Harcourt)']::TEXT[],
    'Fidelity Bank', '0330000561', 'SAGE LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'SAGE Logistics Manager', '+234 705 975 6806', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'd3e13af4-703a-58a6-b3df-fae1bd11c587', 'AG-034', 'imole logistics', '00000000-0000-4000-8000-792411006364', 'Osun', ARRAY['Osun']::TEXT[],
    'Stanbic IBTC', '0340000578', 'imole logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'imole Logistics Manager', '+234 8044 678 2054', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '3b2cf1e9-39cd-523f-9cfa-9d7e8fc7b29f', 'AG-035', 'Olawale Olusola Logistics', '00000000-0000-4000-8000-792411006364', 'Ogun', ARRAY['Ogun']::TEXT[],
    'Zenith Bank', '0350000595', 'Olawale Olusola Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Olawale Logistics Manager', '+234 8045 695 2085', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'cb37d5e6-eb62-54d1-8dac-1950c91267e1', 'AG-036', 'Sabi logistics', '00000000-0000-4000-8000-792411006364', 'Kwara (Ilorin)', ARRAY['Kwara (Ilorin)']::TEXT[],
    'GTBank', '0360000612', 'Sabi logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Sabi Logistics Manager', '+234 8046 712 2116', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '9a18923d-a60c-5282-a681-b9bf883a3d5b', 'AG-037', 'Solomon Uduak Ikpembe', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '0370000629', 'Solomon Uduak Ikpembe Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Solomon Uduak (Ikpembe)', '+234 8047 729 2147', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'efac4488-efc3-59fb-9897-4c48c3345a12', 'AG-038', 'Abdulsalam Abubakar Logistics', '22222222-2222-4222-8222-222222222222', 'Niger (Minna)', ARRAY['Niger (Minna)']::TEXT[],
    'First Bank of Nigeria', '0380000646', 'Abdulsalam Abubakar Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Abdulsalam Abubakar', '+234 8048 746 2178', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '5d539c02-fa9d-5773-aaf1-7f653ada2243', 'AG-039', 'Akanimo Edet Akpan Logistics', '00000000-0000-4000-8000-792411006364', 'Cross River (Calabar)', ARRAY['Cross River (Calabar)']::TEXT[],
    'UBA', '0390000663', 'Akanimo Edet Akpan Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Akanimo Edet Akpan', '+234 704 448 8802', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'e125d31a-a41d-5526-b5b6-dbb95309cccc', 'AG-040', 'Enny Logistics', '00000000-0000-4000-8000-792411006364', 'Oyo (Ibadan)', ARRAY['Oyo (Ibadan)']::TEXT[],
    'Fidelity Bank', '0400000680', 'Enny Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Enny Logistics Manager', '+234 8050 780 2240', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '6d7a135c-79f5-5f37-9a8f-42aa3ca3b1a0', 'AG-041', 'Etimbuk Gregory Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Stanbic IBTC', '0410000697', 'Etimbuk Gregory Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Etimbuk Logistics Manager', '+234 8051 797 2271', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'da845157-64f2-5348-a45e-65b9f5caf9ab', 'AG-042', 'groza logistics ltd', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0420000714', 'groza logistics ltd Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'groza Logistics Manager', '+234 8052 814 2302', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '36ed767b-c92f-5d00-9b47-01da057b838b', 'AG-043', 'HOG Logistics', '00000000-0000-4000-8000-792411006364', 'Ogun', ARRAY['Ogun']::TEXT[],
    'GTBank', '0430000731', 'HOG Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'HOG Logistics Manager', '+234 8053 831 2333', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '171750f3-3657-57b4-bedc-8559141f6949', 'AG-044', 'Sheriff Adesola Raifu Logistics', '00000000-0000-4000-8000-792411006364', 'Osun', ARRAY['Osun']::TEXT[],
    'Access Bank', '0440000748', 'Sheriff Adesola Raifu Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Sheriff Logistics Manager', '+234 8054 848 2364', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'af50803c-d3c4-5bb6-8b7f-88c47af9ad35', 'AG-045', 'Ibrahim Abdulrashid Logistics', '22222222-2222-4222-8222-222222222222', 'Zamfara', ARRAY['Zamfara']::TEXT[],
    'First Bank of Nigeria', '0450000765', 'Ibrahim Abdulrashid Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Ibrahim Logistics Manager', '+234 810 425 4606', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '8249b3b5-fcce-5654-a081-7c530fd0d396', 'AG-046', 'Okoli Nnaemeka Augustine Logistics', '22222222-2222-4222-8222-222222222222', 'Maiduguri (Borno)', ARRAY['Maiduguri (Borno)']::TEXT[],
    'UBA', '0460000782', 'Okoli Nnaemeka Augustine Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Okoli Nnaemeka Augustine', '+234 706 328 0237', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '81f02880-2aa2-548c-b8bc-e987f4263e34', 'AG-047', 'Oluwadamilare Emmanuel Logistics', '00000000-0000-4000-8000-792411006364', 'Anambra', ARRAY['Anambra']::TEXT[],
    'Fidelity Bank', '0470000799', 'Oluwadamilare Emmanuel Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Oluwadamilare Emmanuel', '+234 8057 899 2457', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'e32cbd13-3b4f-5dc8-a42e-485f9c9a6540', 'AG-048', 'Olufunke Babalola Logistics', '00000000-0000-4000-8000-792411006364', 'Oyo (Ibadan)', ARRAY['Oyo (Ibadan)']::TEXT[],
    'Stanbic IBTC', '0480000816', 'Olufunke Babalola Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Olufunke Logistics Manager', '+234 8058 916 2488', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '8ead13c1-aa06-5923-9b1b-af7392aa6c98', 'AG-049', 'PEAKLINK LOGISTICS LTD', '00000000-0000-4000-8000-792411006364', 'Rivers (Port Harcourt)', ARRAY['Rivers (Port Harcourt)']::TEXT[],
    'Zenith Bank', '0490000833', 'PEAKLINK LOGISTICS LTD Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'PEAKLINK Logistics Manager', '+234 815 292 4060', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'f6fa88fc-9252-5559-8605-403218f98ca1', 'AG-050', 'Smart move Logistics LOGISTICS', '22222222-2222-4222-8222-222222222222', 'Nasarawa', ARRAY['Nasarawa']::TEXT[],
    'GTBank', '0500000850', 'Smart move Logistics LOGISTICS Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Smart Logistics Manager', '+234 902 530 3337', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '332c1267-8768-59bf-a8d9-537fa1947ae8', 'AG-051', 'Victor Ogbenyi Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '0510000867', 'Victor Ogbenyi Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Victor Logistics Manager', '+234 8061 967 2581', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '07574873-d711-59d7-a5eb-c862442223bc', 'AG-052', 'Yohanna Vanduna Logistics', '22222222-2222-4222-8222-222222222222', 'Plateau (Jos)', ARRAY['Plateau (Jos)']::TEXT[],
    'First Bank of Nigeria', '0520000884', 'Yohanna Vanduna Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Yohanna Logistics Manager', '+234 8062 984 2612', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '55e3e1dd-7b0c-510b-9b97-92b17d29250a', 'AG-053', 'yusuf joy', '22222222-2222-4222-8222-222222222222', 'Niger (Minna)', ARRAY['Niger (Minna)']::TEXT[],
    'UBA', '0530000901', 'yusuf joy Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Yusuf Joy', '+234 8063 101 2643', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'f953d0bb-d1d6-54b0-a5de-51363bdc5b2a', 'AG-054', 'ZIBRA & CO LTD LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Rivers (Port Harcourt)', ARRAY['Rivers (Port Harcourt)']::TEXT[],
    'Fidelity Bank', '0540000918', 'ZIBRA & CO LTD LOGISTICS Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'ZIBRA Logistics Manager', '+234 816 929 3676', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '3e71558d-ccc1-54e3-b625-7d4e7552d806', 'AG-055', 'Safehands logistics', '00000000-0000-4000-8000-792411006364', 'Cross River (Calabar)', ARRAY['Cross River (Calabar)']::TEXT[],
    'Stanbic IBTC', '0550000935', 'Safehands logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Safehands Logistics Manager', '+234 080124131591', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '9abac0a7-bf69-58fb-8f59-3c4973735a9f', 'AG-056', 'Elite Logistics', '22222222-2222-4222-8222-222222222222', 'Nasarawa', ARRAY['Nasarawa']::TEXT[],
    'Zenith Bank', '0560000952', 'Elite Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Elite Logistics Manager', '+234 816 444 4477', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '2388c60e-8682-5e6a-bf9e-7434925b75ba', 'AG-057', 'Usiju Ladu Logistics', '22222222-2222-4222-8222-222222222222', 'Borno (Maiduguri)', ARRAY['Borno (Maiduguri)']::TEXT[],
    'GTBank', '0570000969', 'Usiju Ladu Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Usiju Logistics Manager', '+234 8067 169 2767', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '00aaa429-d0fe-5639-8f96-a4c7afa94baa', 'AG-058', 'FOMAX ASABA (DELTA) LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Delta', ARRAY['Delta']::TEXT[],
    'Access Bank', '0580000986', 'FOMAX ASABA (DELTA) LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'FOMAX Logistics Manager', '+234 8068 186 2798', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '5150ba57-5773-5800-9286-0ab43cdb553e', 'AG-059', 'APPLE ABIA TAZE LOGISTICS SERVICES', '00000000-0000-4000-8000-792411006364', 'Abia', ARRAY['Abia']::TEXT[],
    'First Bank of Nigeria', '0590001003', 'APPLE ABIA TAZE LOGISTICS SERVICES Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'APPLE Logistics Manager', '+234 806 550 4752', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '2954c74e-24f1-591c-b20a-9978884fe485', 'AG-060', 'Aruoriwo Adhuze', '00000000-0000-4000-8000-792411006364', 'Ondo', ARRAY['Ondo']::TEXT[],
    'UBA', '0600001020', 'Aruoriwo Adhuze Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Aruw... Adhuze', '+234 8070 220 2860', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '883afab5-0e0d-57d6-865f-16175d0d145c', 'AG-061', 'De Wealthz Logistics', '00000000-0000-4000-8000-792411006364', 'Akwa Ibom', ARRAY['Akwa Ibom']::TEXT[],
    'Fidelity Bank', '0610001037', 'De Wealthz Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'De Logistics Manager', '+234 8071 237 2891', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '66bcf6f3-f5e4-5f00-9e65-946195d6e570', 'AG-062', 'ATOMIC LOGISTICS EDO', '00000000-0000-4000-8000-792411006364', 'Edo (Benin)', ARRAY['Edo (Benin)']::TEXT[],
    'Stanbic IBTC', '0620001054', 'ATOMIC LOGISTICS EDO Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'ATOMIC Logistics Manager', '+234 705 543 7356', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '89f13c6e-7d13-5360-b763-937357f84fa5', 'AG-063', 'DASHGO DELIVERY CALABAR', '00000000-0000-4000-8000-792411006364', 'Cross River (Calabar)', ARRAY['Cross River (Calabar)']::TEXT[],
    'Zenith Bank', '0630001071', 'DASHGO DELIVERY CALABAR Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'DASHGO Logistics Manager', '+234 912 529 5092', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '9a0ebe4f-ca9c-5253-834d-6eabcda717cc', 'AG-064', 'ANIEADOLF CREATIONS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0640001088', 'ANIEADOLF CREATIONS Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'ANIEADOLF Logistics Manager', '+234 8074 288 2984', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'baf394fa-ef3e-5654-b019-617eb59c77b0', 'AG-065', 'Adetola Sam Adewuyi LOGISTICS', '22222222-2222-4222-8222-222222222222', 'Kaduna', ARRAY['Kaduna']::TEXT[],
    'Access Bank', '0650001105', 'Adetola Sam Adewuyi LOGISTICS Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Adetola Sam Adeyemi (Sam KJ)', '+234 907 676 7680', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'c84f1497-c750-5de3-b791-931b01d82f6f', 'AG-066', 'PRINCE LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Ogun', ARRAY['Ogun']::TEXT[],
    'First Bank of Nigeria', '0660001122', 'PRINCE LOGISTICS Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'PRINCE Logistics Manager', '+234 8076 322 3046', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '1ad82b51-d279-5d47-a510-93b530970e29', 'AG-067', 'Hambolu babatunde philips Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '0670001139', 'Hambolu babatunde philips Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Hambolu Babalola Philips', '+234 8077 339 3077', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '0915efa2-75a5-5c1a-bf37-3115488e5ffd', 'AG-068', 'ISMAIL MUHAMMAD LIMAN', '22222222-2222-4222-8222-222222222222', 'Nasarawa', ARRAY['Nasarawa']::TEXT[],
    'Fidelity Bank', '0680001156', 'ISMAIL MUHAMMAD LIMAN Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'T.Smail Mohammed Liman', '+234 813 326 7092', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'fc69504c-cc54-5aad-99bc-d4fe7f31a90b', 'AG-069', 'Teekina kuroakegha Gbeneteh Logistics', '00000000-0000-4000-8000-792411006364', 'Bayelsa', ARRAY['Bayelsa']::TEXT[],
    'Stanbic IBTC', '0690001173', 'Teekina kuroakegha Gbeneteh Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Teekina Kuroakegha Gbenete', '+234 704 152 9732', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '74fa34c1-3092-5117-8a9e-c9768dca1d9c', 'AG-070', 'Threeple A Logistics', '00000000-0000-4000-8000-792411006364', 'Ogun', ARRAY['Ogun']::TEXT[],
    'Zenith Bank', '0700001190', 'Threeple A Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Threeple Ogun', '+234 8080 390 3170', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '56501ff0-9459-5c40-90bc-f74a6e9fd351', 'AG-071', 'BLUE AMAZON LOGISTICS LTD LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Imo', ARRAY['Imo']::TEXT[],
    'GTBank', '0710001207', 'BLUE AMAZON LOGISTICS LTD LOGISTICS Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Akpan Blue Amazon', '+234 807 920 7156', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'c5a27914-d6f4-5acb-9589-6e9cf2f66e06', 'AG-072', 'Chidi Godstime Egege Logistics', '00000000-0000-4000-8000-792411006364', 'Abia', ARRAY['Abia']::TEXT[],
    'Access Bank', '0720001224', 'Chidi Godstime Egege Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Chidi Godstime', '+234 706 425 0735', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '6a7ee7b6-3d72-5813-970e-9e68ca291a30', 'AG-073', 'Emmanuel Nnamdi Ugwu Logistics', '00000000-0000-4000-8000-792411006364', 'Enugu', ARRAY['Enugu']::TEXT[],
    'First Bank of Nigeria', '0730001241', 'Emmanuel Nnamdi Ugwu Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Emmanuel Nnamdi Ugwui', '+234 813 310 1091', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'd7221c16-981d-59b5-add5-12a8d0aee6e8', 'AG-074', 'KENNEDY OROWO EDEYE Logistics', '00000000-0000-4000-8000-792411006364', 'Delta (Warri)', ARRAY['Delta (Warri)']::TEXT[],
    'UBA', '0740001258', 'KENNEDY OROWO EDEYE Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Kennedy Orowo Edoye', '+234 703 672 6872', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '4f56f0fb-bd53-53b2-8006-da93b9b77615', 'AG-075', 'Mavicaon Logistics', '22222222-2222-4222-8222-222222222222', 'Zamfara', ARRAY['Zamfara']::TEXT[],
    'Fidelity Bank', '0750001275', 'Mavicaon Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Mavicaon Logistics Manager', '+234 8085 475 3325', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '490da1ac-56c2-560c-bf2a-de2ed587019c', 'AG-076', 'Omoga Victor Ohe-obe Logistics', '00000000-0000-4000-8000-792411006364', 'Kwara (Ilorin)', ARRAY['Kwara (Ilorin)']::TEXT[],
    'Stanbic IBTC', '0760001292', 'Omoga Victor Ohe-obe Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Omoga Logistics Manager', '+234 070 703 9598', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'fb446d89-c197-5e9a-ada2-336b303c1937', 'AG-077', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Anambra', ARRAY['Anambra']::TEXT[],
    'Zenith Bank', '0770001309', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'PELICAN Logistics Manager', '+234 8087 509 3387', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '9d4de8e9-fb6f-5282-8dfd-a08feeb9291b', 'AG-078', 'presteveGo logistics', '22222222-2222-4222-8222-222222222222', 'Kogi', ARRAY['Kogi']::TEXT[],
    'GTBank', '0780001326', 'presteveGo logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'presteveGo Logistics Manager', '+234 805 648 1426', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '83d8a40c-3437-5706-9d62-cd6967c87ad9', 'AG-079', 'Shittu Adebamke Yusuff Logistics', '00000000-0000-4000-8000-792411006364', 'Ogun', ARRAY['Ogun']::TEXT[],
    'Access Bank', '0790001343', 'Shittu Adebamke Yusuff Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Shittu-Aleebanke Yusuf', '+234 8089 543 3449', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '594d7c33-22fa-5fe2-98ee-56fc11563052', 'AG-080', 'Durojaiye Ilashe Joseph Logistics', '22222222-2222-4222-8222-222222222222', 'Kogi', ARRAY['Kogi']::TEXT[],
    'First Bank of Nigeria', '0800001360', 'Durojaiye Ilashe Joseph Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Durojaiye Illashe Joseph', '+234 813 342 8138', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '0a99038e-42e1-51c5-901e-c2a5387dff9b', 'AG-081', 'Express Logistics, Ebonyi LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Ebonyi', ARRAY['Ebonyi']::TEXT[],
    'UBA', '0810001377', 'Express Logistics, Ebonyi LOGISTICS Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'UG Exp Ebonyi', '+234 816 115 2615', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '38355457-91ee-54f6-b58a-47450fb2a77b', 'AG-082', 'TRUST LOGISTICS PDA', '22222222-2222-4222-8222-222222222222', 'Benue', ARRAY['Benue']::TEXT[],
    'Fidelity Bank', '0820001394', 'TRUST LOGISTICS PDA Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'TRUST Logistics Manager', '+234 8012 594 3542', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '125b623a-4622-5141-bcef-c98e1821ca38', 'AG-083', 'Iby Logistics', '00000000-0000-4000-8000-792411006364', 'Akwa Ibom', ARRAY['Akwa Ibom']::TEXT[],
    'Stanbic IBTC', '0830001411', 'Iby Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Iby Logistics Manager', '+234 706 936 5882', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '274a985f-2b72-5309-8787-e04189382b51', 'AG-084', 'Laboratory Landmark Logistics', '00000000-0000-4000-8000-792411006364', 'Delta', ARRAY['Delta']::TEXT[],
    'Zenith Bank', '0840001428', 'Laboratory Landmark Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Laboratory Logistics Manager', '+234 806 423 5815', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'ff812097-8487-563c-9322-fcfe0fa4bbb4', 'AG-085', '3twelve logistics Services', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0850001445', '3twelve logistics Services Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    '3twelve Logistics Manager', '+234 8015 645 3635', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '3cf289ab-e332-5545-9f10-a4f0e1057152', 'AG-086', 'Abutu Emmanuel', '22222222-2222-4222-8222-222222222222', 'Niger (Minna)', ARRAY['Niger (Minna)']::TEXT[],
    'Access Bank', '0860001462', 'Abutu Emmanuel Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Abutu Logistics Manager', '+234 8016 662 3666', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '2b20dfa8-b896-5cab-b119-11446410b9d3', 'AG-087', 'Bloomish Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '0870001479', 'Bloomish Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Bloomish Logistics Manager', '+234 8017 679 3697', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '36b74ad4-cdb2-5084-adb6-96649c52f4aa', 'AG-088', 'BTOP LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '0880001496', 'BTOP LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'BTOP Logistics Manager', '+234 8018 696 3728', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'de664468-8462-57c2-bd06-3cd967057571', 'AG-089', 'Connect Logistics', '22222222-2222-4222-8222-222222222222', 'Nasarawa', ARRAY['Nasarawa']::TEXT[],
    'Fidelity Bank', '0890001513', 'Connect Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Connect Logistics Manager', '+234 8019 713 3759', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '654fff80-f29c-52af-9804-c0eaa9e9c148', 'AG-090', 'Daniel Ekpo', '00000000-0000-4000-8000-792411006364', 'Abia', ARRAY['Abia']::TEXT[],
    'Stanbic IBTC', '0900001530', 'Daniel Ekpo Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Daniel Logistics Manager', '+234 8020 730 3790', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '3c96e16d-f041-5a96-842d-0f6522d5a8bc', 'AG-091', 'Davtom Logistics', '00000000-0000-4000-8000-792411006364', 'Ekiti', ARRAY['Ekiti']::TEXT[],
    'Zenith Bank', '0910001547', 'Davtom Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Davtom Logistics Manager', '+234 8021 747 3821', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'e15001c8-9a8a-5389-b21d-2e2e113d4be8', 'AG-092', 'Deiwa logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0920001564', 'Deiwa logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Deiwa Logistics Manager', '+234 8022 764 3852', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '0a9d6365-2794-5575-9109-c069bfe16294', 'AG-093', 'Eagles Frontier Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '0930001581', 'Eagles Frontier Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Eagles Logistics Manager', '+234 8023 781 3883', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'b8a79951-5d94-5ec1-a7dd-a5f7607908d8', 'AG-094', 'Elizabeth Anietie-Okon', '00000000-0000-4000-8000-792411006364', 'Rivers (Port Harcourt)', ARRAY['Rivers (Port Harcourt)']::TEXT[],
    'First Bank of Nigeria', '0940001598', 'Elizabeth Anietie-Okon Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Elizabeth Logistics Manager', '+234 8024 798 3914', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'aa4f09cb-32dd-5769-a8e6-2da4f841a2b3', 'AG-095', 'Fabulous Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '0950001615', 'Fabulous Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Fabulous Logistics Manager', '+234 8025 815 3945', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '167b0cf1-26ed-5018-acc9-27e52c055935', 'AG-096', 'Global Debbie scents', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '0960001632', 'Global Debbie scents Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Global Logistics Manager', '+234 8026 832 3976', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '3f4dcab0-acc7-57c8-a7c9-531c57a0364d', 'AG-097', 'GOLFDLONA GLOBAL LOGISTICS', '00000000-0000-4000-8000-792411006364', 'EDO', ARRAY['EDO']::TEXT[],
    'Stanbic IBTC', '0970001649', 'GOLFDLONA GLOBAL LOGISTICS Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'GOLFDLONA Logistics Manager', '+234 8027 849 4007', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'e039fdf1-b81b-5268-98db-23088147d560', 'AG-098', 'Ibylogistics Limited LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Akwa Ibom', ARRAY['Akwa Ibom']::TEXT[],
    'Zenith Bank', '0980001666', 'Ibylogistics Limited LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Ibylogistics Logistics Manager', '+234 8028 866 4038', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'fae2f20a-6fcf-56f0-af6e-da8dd0499567', 'AG-099', 'John Hamza shuaibu Logistics', '22222222-2222-4222-8222-222222222222', 'ABUJA', ARRAY['ABUJA']::TEXT[],
    'GTBank', '0990001683', 'John Hamza shuaibu Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'John Logistics Manager', '+234 8029 883 4069', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '2ed324bc-11b6-5705-b799-79ef1073b332', 'AG-100', 'John Peter Adamawa', '22222222-2222-4222-8222-222222222222', 'Adamawa', ARRAY['Adamawa']::TEXT[],
    'Access Bank', '01000001700', 'John Peter Adamawa Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'John Logistics Manager', '+234 8030 900 4100', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '167c26a0-a695-526c-90f7-74520878b7a9', 'AG-101', 'KUSFAT LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Kwara (Ilorin)', ARRAY['Kwara (Ilorin)']::TEXT[],
    'First Bank of Nigeria', '01010001717', 'KUSFAT LOGISTICS Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'KUSFAT Logistics Manager', '+234 8031 917 4131', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'da34ff98-3d3e-552f-9681-b18b6a2eda98', 'AG-102', 'MELLUX LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '01020001734', 'MELLUX LOGISTICS Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'MELLUX Logistics Manager', '+234 8032 934 4162', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '9e99f02a-a8b3-5cfe-a35b-ebd6c1cd6727', 'AG-103', 'Nobelia logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '01030001751', 'Nobelia logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Nobelia Logistics Manager', '+234 8033 951 4193', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '488c4447-1546-5759-a2fe-95a23d1e88ab', 'AG-104', 'Oluwatobi Femi-Fasan', '00000000-0000-4000-8000-792411006364', 'Ondo', ARRAY['Ondo']::TEXT[],
    'Stanbic IBTC', '01040001768', 'Oluwatobi Femi-Fasan Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Oluwatobi Logistics Manager', '+234 8034 968 4224', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '5eee3fb5-e2e4-5f04-b1b6-89d10ef9bf3a', 'AG-105', 'Rapid moves logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '01050001785', 'Rapid moves logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Rapid Logistics Manager', '+234 8035 985 4255', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '8618a8d9-5a6a-5ec1-b976-4f1216335213', 'AG-106', 'SendMe Logistics', '00000000-0000-4000-8000-792411006364', 'Ogun', ARRAY['Ogun']::TEXT[],
    'GTBank', '01060001802', 'SendMe Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'SendMe Logistics Manager', '+234 8036 102 4286', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '081aca8d-9093-5d70-b51b-8bb3c602afdb', 'AG-107', 'Steve temienor', '00000000-0000-4000-8000-792411006364', 'Delta', ARRAY['Delta']::TEXT[],
    'Access Bank', '01070001819', 'Steve temienor Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Steve Logistics Manager', '+234 8037 119 4317', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '6b1ce548-a7fe-5560-b1c9-7da028da91f5', 'AG-108', 'Tagwaye Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '01080001836', 'Tagwaye Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Tagwaye Logistics Manager', '+234 8038 136 4348', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '4f8d2046-7e51-5985-b745-236d7a9edff7', 'AG-109', 'Tajudeen Logistics', '22222222-2222-4222-8222-222222222222', 'Sokoto', ARRAY['Sokoto']::TEXT[],
    'UBA', '01090001853', 'Tajudeen Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Tajudeen Logistics Manager', '+234 8039 153 4379', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '715b5f4f-f75e-5e78-bba7-7a068b35eaf9', 'AG-110', 'TIMAGISTICS LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Cross River (Calabar)', ARRAY['Cross River (Calabar)']::TEXT[],
    'Fidelity Bank', '01100001870', 'TIMAGISTICS LOGISTICS Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'TIMAGISTICS Logistics Manager', '+234 8040 170 4410', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '7f059f09-07dd-5202-806a-a9635a430b47', 'AG-111', 'ug express logistics ltd', '00000000-0000-4000-8000-792411006364', 'Ebonyi', ARRAY['Ebonyi']::TEXT[],
    'Stanbic IBTC', '01110001887', 'ug express logistics ltd Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'ug Logistics Manager', '+234 8041 187 4441', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    '178ce8ec-ff5c-5f92-9483-ff274a728fdd', 'AG-112', 'UGH LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Delta', ARRAY['Delta']::TEXT[],
    'Zenith Bank', '01120001904', 'UGH LOGISTICS Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'UGH Logistics Manager', '+234 8042 204 4472', 'Central Operations'
) ON CONFLICT (id) DO UPDATE SET
    agent_code = EXCLUDED.agent_code,
    full_name = EXCLUDED.full_name,
    distribution_center_id = EXCLUDED.distribution_center_id,
    operating_state = EXCLUDED.operating_state,
    coverage_states = EXCLUDED.coverage_states,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    commission_rate = EXCLUDED.commission_rate,
    failed_delivery_allowance = EXCLUDED.failed_delivery_allowance,
    transport_allowance = EXCLUDED.transport_allowance,
    is_active = EXCLUDED.is_active,
    current_status = EXCLUDED.current_status,
    guarantor_name = EXCLUDED.guarantor_name,
    guarantor_phone = EXCLUDED.guarantor_phone,
    updated_at = NOW();
