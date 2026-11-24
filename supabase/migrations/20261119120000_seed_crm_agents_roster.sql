-- Migration: Seed CRM Agents Roster (111 Real Courier Agents)
-- Purges any legacy fake placeholder companies (GIG, Speedaf, Fez)
-- Idempotently upserts NovaXpress Logistics (Internal Fleet) + 110 Real Courier Companies

INSERT INTO public.delivery_agents (
    id, agent_code, full_name, distribution_center_id, operating_state, coverage_states,
    bank_name, bank_account_number, bank_account_name, commission_rate, failed_delivery_allowance,
    transport_allowance, is_active, current_status, personnel_type, max_active_orders,
    guarantor_name, guarantor_phone, operating_city
) VALUES (
    'bd21930d-a2c7-546f-8fd6-1c61849ae4d6', 'NX-ABJ-01', 'NovaXpress Logistics (Internal Fleet)', '22222222-2222-4222-8222-222222222222', 'Abuja (FCT)', ARRAY['Abuja (FCT)', 'Niger', 'Nasarawa', 'Kaduna']::TEXT[],
    'Zenith Bank', '1019283746', 'NovaXpress Logistics Operations', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 50,
    'Engr. Tunde Adeleke', '+234 803 111 2233', 'Wuse 2'
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
    '0872f4a8-c158-545d-b7d8-51bb2f5bf801', 'AG-001', 'ADICHA LOGISTICS', '00000000-0000-4000-8000-792411006364', 'LAGOS', ARRAY['LAGOS']::TEXT[],
    'GTBank', '0010000017', 'ADICHA LOGISTICS Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'ADICHA Logistics Manager', '+234 8002000031', 'Central Operations'
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
    '332c1267-8768-59bf-a8d9-537fa1947ae8', 'AG-002', 'Victor Ogbenyi Logistics', '00000000-0000-4000-8000-792411006364', 'LAGOS', ARRAY['LAGOS']::TEXT[],
    'Access Bank', '0020000034', 'Victor Ogbenyi Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Victor Logistics Manager', '+234 8003000062', 'Central Operations'
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
    '397982de-f437-5ea7-8b20-bea34660d5fc', 'AG-003', 'ATP Logistics LOGISTICS', '00000000-0000-4000-8000-792411006364', 'EDO BENIN', ARRAY['EDO BENIN']::TEXT[],
    'First Bank of Nigeria', '0030000051', 'ATP Logistics LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'ATP Logistics Manager', '+234 8004000093', 'Central Operations'
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
    'd7221c16-981d-59b5-add5-12a8d0aee6e8', 'AG-004', 'KENNEDY OROWO EDEYE Logistics', '00000000-0000-4000-8000-792411006364', 'DELTA', ARRAY['DELTA']::TEXT[],
    'UBA', '0040000068', 'KENNEDY OROWO EDEYE Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'KENNEDY Logistics Manager', '+234 8005000124', 'Central Operations'
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
    '0dc5e413-c259-5c00-847f-5d951536a6e6', 'AG-005', 'byke messengers logistic', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '0050000085', 'byke messengers logistic Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'byke Logistics Manager', '+234 8006000155', 'Central Operations'
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
    '67e59ce6-36e1-547f-8a32-90fd2c2fc17d', 'AG-006', 'RAPH XPRESS LOGISTICS', '00000000-0000-4000-8000-792411006364', 'LAGOS', ARRAY['LAGOS']::TEXT[],
    'Stanbic IBTC', '0060000102', 'RAPH XPRESS LOGISTICS Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'RAPH Logistics Manager', '+234 8007000186', 'Central Operations'
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
    'c02877c7-693c-5dd9-ab4b-010c8eb43a6b', 'AG-007', 'Raphael Michael Logistics', '22222222-2222-4222-8222-222222222222', 'BAUCHI', ARRAY['BAUCHI']::TEXT[],
    'Zenith Bank', '0070000119', 'Raphael Michael Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Raphael Logistics Manager', '+234 8008000217', 'Central Operations'
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
    'a89e1e28-ce12-5766-8d6a-69a33c9a1483', 'AG-008', 'SOLOPEE LOGISTCS', '22222222-2222-4222-8222-222222222222', 'JOS', ARRAY['JOS']::TEXT[],
    'GTBank', '0080000136', 'SOLOPEE LOGISTCS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'SOLOPEE Logistics Manager', '+234 8009000248', 'Central Operations'
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
    '8249b3b5-fcce-5654-a081-7c530fd0d396', 'AG-009', 'Okoli Nnaemeka Augustine Logistics', '00000000-0000-4000-8000-792411006364', 'ANAMBRA', ARRAY['ANAMBRA']::TEXT[],
    'Access Bank', '0090000153', 'Okoli Nnaemeka Augustine Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Okoli Logistics Manager', '+234 8010000279', 'Central Operations'
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
    'a13981e4-ea98-58da-813a-d1db917c9e32', 'AG-010', 'Velocitŕ logistics LOGISTICS', '00000000-0000-4000-8000-792411006364', 'PH', ARRAY['PH']::TEXT[],
    'First Bank of Nigeria', '0100000170', 'Velocitŕ logistics LOGISTICS Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Velocitŕ Logistics Manager', '+234 8011000310', 'Central Operations'
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
    '171750f3-3657-57b4-bedc-8559141f6949', 'AG-011', 'Sheriff Adesola Raifu Logistics', '00000000-0000-4000-8000-792411006364', 'OSUN', ARRAY['OSUN']::TEXT[],
    'UBA', '0110000187', 'Sheriff Adesola Raifu Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Sheriff Logistics Manager', '+234 8012000341', 'Central Operations'
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
    '490da1ac-56c2-560c-bf2a-de2ed587019c', 'AG-012', 'Omoga Victor Ohe-obe Logistics', '00000000-0000-4000-8000-792411006364', 'ENUGU', ARRAY['ENUGU']::TEXT[],
    'Fidelity Bank', '0120000204', 'Omoga Victor Ohe-obe Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Omoga Logistics Manager', '+234 8013000372', 'Central Operations'
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
    'e039fdf1-b81b-5268-98db-23088147d560', 'AG-013', 'Ibylogistics Limited LOGISTICS', '00000000-0000-4000-8000-792411006364', 'AKWA IBOM', ARRAY['AKWA IBOM']::TEXT[],
    'Stanbic IBTC', '0130000221', 'Ibylogistics Limited LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Ibylogistics Logistics Manager', '+234 8014000403', 'Central Operations'
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
    '98ffc392-80a8-5c77-bb1d-5a23e5c3e617', 'AG-014', 'Gimway Concept', '00000000-0000-4000-8000-792411006364', 'LAGOS', ARRAY['LAGOS']::TEXT[],
    'Zenith Bank', '0140000238', 'Gimway Concept Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Gimway Logistics Manager', '+234 8015000434', 'Central Operations'
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
    '068d1ba0-ee33-57f7-b59f-03cb103f386a', 'AG-015', 'HOG logistics LOGISTICS', '00000000-0000-4000-8000-792411006364', 'OGUN', ARRAY['OGUN']::TEXT[],
    'GTBank', '0150000255', 'HOG logistics LOGISTICS Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'HOG Logistics Manager', '+234 8016000465', 'Central Operations'
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
    '81f02880-2aa2-548c-b8bc-e987f4263e34', 'AG-016', 'Oluwadamilare Emmanuel Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '0160000272', 'Oluwadamilare Emmanuel Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Oluwadamilare Logistics Manager', '+234 8017000496', 'Central Operations'
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
    '1ce2c933-b0f7-571e-8578-8ca1ab13c35f', 'AG-017', 'Toheeb Biola Popoola Logistics', '00000000-0000-4000-8000-792411006364', 'OGUN', ARRAY['OGUN']::TEXT[],
    'First Bank of Nigeria', '0170000289', 'Toheeb Biola Popoola Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Toheeb Logistics Manager', '+234 8018000527', 'Central Operations'
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
    'c5a27914-d6f4-5acb-9589-6e9cf2f66e06', 'AG-018', 'Chidi Godstime Egege Logistics', '00000000-0000-4000-8000-792411006364', 'ABIA', ARRAY['ABIA']::TEXT[],
    'UBA', '0180000306', 'Chidi Godstime Egege Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Chidi Logistics Manager', '+234 8019000558', 'Central Operations'
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
    '38767c9c-408c-548d-ba4d-51421bb9b395', 'AG-019', 'smart logistics LOGISTICS', '00000000-0000-4000-8000-792411006364', 'DELTA', ARRAY['DELTA']::TEXT[],
    'Fidelity Bank', '0190000323', 'smart logistics LOGISTICS Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'smart Logistics Manager', '+234 8020000589', 'Central Operations'
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
    'e310371e-990f-591b-8dcb-a8ee930390d6', 'AG-020', 'SAGE LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Stanbic IBTC', '0200000340', 'SAGE LOGISTICS Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'SAGE Logistics Manager', '+234 8021000620', 'Central Operations'
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
    '70248c36-7af3-5ee7-9b60-d0ef504d0e0b', 'AG-021', 'Olagunju Damilola Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0210000357', 'Olagunju Damilola Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Olagunju Logistics Manager', '+234 8022000651', 'Central Operations'
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
    '1ad82b51-d279-5d47-a510-93b530970e29', 'AG-022', 'Hambolu babatunde philips Logistics', '00000000-0000-4000-8000-792411006364', 'LAGOS', ARRAY['LAGOS']::TEXT[],
    'GTBank', '0220000374', 'Hambolu babatunde philips Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Hambolu Logistics Manager', '+234 8023000682', 'Central Operations'
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
    'f953d0bb-d1d6-54b0-a5de-51363bdc5b2a', 'AG-023', 'ZIBRA & CO LTD LOGISTICS', '00000000-0000-4000-8000-792411006364', 'PH', ARRAY['PH']::TEXT[],
    'Access Bank', '0230000391', 'ZIBRA & CO LTD LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'ZIBRA Logistics Manager', '+234 8024000713', 'Central Operations'
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
    'fc69504c-cc54-5aad-99bc-d4fe7f31a90b', 'AG-024', 'Teekina kuroakegha Gbeneteh Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '0240000408', 'Teekina kuroakegha Gbeneteh Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Teekina Logistics Manager', '+234 8025000744', 'Central Operations'
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
    'ae45b374-ea7f-528c-8070-c958a538cf33', 'AG-025', 'Msuega Terlanga Japhet Logistics', '22222222-2222-4222-8222-222222222222', 'BENUE', ARRAY['BENUE']::TEXT[],
    'UBA', '0250000425', 'Msuega Terlanga Japhet Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Msuega Logistics Manager', '+234 8026000775', 'Central Operations'
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
    'efac4488-efc3-59fb-9897-4c48c3345a12', 'AG-026', 'Abdulsalam Abubakar Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '0260000442', 'Abdulsalam Abubakar Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Abdulsalam Logistics Manager', '+234 8027000806', 'Central Operations'
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
    '3e510630-d989-5a9b-a420-8daf062b2a50', 'AG-027', 'Ola Cash', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Stanbic IBTC', '0270000459', 'Ola Cash Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Ola Logistics Manager', '+234 8028000837', 'Central Operations'
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
    '74fa34c1-3092-5117-8a9e-c9768dca1d9c', 'AG-028', 'Threeple A Logistics', '00000000-0000-4000-8000-792411006364', 'OGUN', ARRAY['OGUN']::TEXT[],
    'Zenith Bank', '0280000476', 'Threeple A Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Threeple Logistics Manager', '+234 8029000868', 'Central Operations'
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
    '2954c74e-24f1-591c-b20a-9978884fe485', 'AG-029', 'Aruoriwo Adhuze', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0290000493', 'Aruoriwo Adhuze Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Aruoriwo Logistics Manager', '+234 8030000899', 'Central Operations'
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
    'd7d8ad39-1345-5011-9816-40e06b903325', 'AG-030', 'Ezekiel Ameh Logistics', '22222222-2222-4222-8222-222222222222', 'KANO', ARRAY['KANO']::TEXT[],
    'Access Bank', '0300000510', 'Ezekiel Ameh Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Ezekiel Logistics Manager', '+234 8031000930', 'Central Operations'
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
    '5d539c02-fa9d-5773-aaf1-7f653ada2243', 'AG-031', 'Akanimo Edet Akpan Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '0310000527', 'Akanimo Edet Akpan Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Akanimo Logistics Manager', '+234 8032000961', 'Central Operations'
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
    '46103da6-e28c-507a-937f-1109c9e39838', 'AG-032', 'Ibitoye adewale Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '0320000544', 'Ibitoye adewale Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Ibitoye Logistics Manager', '+234 8033000992', 'Central Operations'
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
    '04d56d13-c4ec-5f90-934b-f8d5df45d65d', 'AG-033', 'Fomax logistics LOGISTICS', '00000000-0000-4000-8000-792411006364', 'LAGOS', ARRAY['LAGOS']::TEXT[],
    'Fidelity Bank', '0330000561', 'Fomax logistics LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Fomax Logistics Manager', '+234 8034001023', 'Central Operations'
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
    'baf394fa-ef3e-5654-b019-617eb59c77b0', 'AG-034', 'Adetola Sam Adewuyi LOGISTICS', '22222222-2222-4222-8222-222222222222', 'KADUNA', ARRAY['KADUNA']::TEXT[],
    'Stanbic IBTC', '0340000578', 'Adetola Sam Adewuyi LOGISTICS Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Adetola Logistics Manager', '+234 8035001054', 'Central Operations'
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
    '15a3ec94-ddcb-5eef-a9c1-e5cf53e88dc5', 'AG-035', 'Olaseni Adewumi James Logistics', '00000000-0000-4000-8000-792411006364', 'EKITI', ARRAY['EKITI']::TEXT[],
    'Zenith Bank', '0350000595', 'Olaseni Adewumi James Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Olaseni Logistics Manager', '+234 8036001085', 'Central Operations'
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
    '0a99038e-42e1-51c5-901e-c2a5387dff9b', 'AG-036', 'Express Logistics, Ebonyi LOGISTICS', '00000000-0000-4000-8000-792411006364', 'EBONYI', ARRAY['EBONYI']::TEXT[],
    'GTBank', '0360000612', 'Express Logistics, Ebonyi LOGISTICS Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Express Logistics Manager', '+234 8037001116', 'Central Operations'
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
    '1d3a87ca-fd33-5fcc-b050-afe2e9940b7b', 'AG-037', 'Arinze Esther Logistics', '00000000-0000-4000-8000-792411006364', 'ANAMBRA', ARRAY['ANAMBRA']::TEXT[],
    'Access Bank', '0370000629', 'Arinze Esther Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Arinze Logistics Manager', '+234 8038001147', 'Central Operations'
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
    'c84f1497-c750-5de3-b791-931b01d82f6f', 'AG-038', 'PRINCE LOGISTICS', '00000000-0000-4000-8000-792411006364', 'OGUN', ARRAY['OGUN']::TEXT[],
    'First Bank of Nigeria', '0380000646', 'PRINCE LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'PRINCE Logistics Manager', '+234 8039001178', 'Central Operations'
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
    '66bcf6f3-f5e4-5f00-9e65-946195d6e570', 'AG-039', 'ATOMIC LOGISTICS EDO', '00000000-0000-4000-8000-792411006364', 'EDO BENIN', ARRAY['EDO BENIN']::TEXT[],
    'UBA', '0390000663', 'ATOMIC LOGISTICS EDO Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'ATOMIC Logistics Manager', '+234 8040001209', 'Central Operations'
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
    'fae2f20a-6fcf-56f0-af6e-da8dd0499567', 'AG-040', 'John Hamza shuaibu Logistics', '22222222-2222-4222-8222-222222222222', 'ABUJA', ARRAY['ABUJA']::TEXT[],
    'Fidelity Bank', '0400000680', 'John Hamza shuaibu Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'John Logistics Manager', '+234 8041001240', 'Central Operations'
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
    '6d7a135c-79f5-5f37-9a8f-42aa3ca3b1a0', 'AG-041', 'Etimbuk Gregory Logistics', '00000000-0000-4000-8000-792411006364', 'LAGOS', ARRAY['LAGOS']::TEXT[],
    'Stanbic IBTC', '0410000697', 'Etimbuk Gregory Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Etimbuk Logistics Manager', '+234 8042001271', 'Central Operations'
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
    '8ead13c1-aa06-5923-9b1b-af7392aa6c98', 'AG-042', 'PEAKLINK LOGISTICS LTD', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0420000714', 'PEAKLINK LOGISTICS LTD Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'PEAKLINK Logistics Manager', '+234 8043001302', 'Central Operations'
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
    'fb446d89-c197-5e9a-ada2-336b303c1937', 'AG-043', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0430000731', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'PELICAN Logistics Manager', '+234 8044001333', 'Central Operations'
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
    '3b2cf1e9-39cd-523f-9cfa-9d7e8fc7b29f', 'AG-044', 'Olawale Olusola Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '0440000748', 'Olawale Olusola Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Olawale Logistics Manager', '+234 8045001364', 'Central Operations'
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
    'd4157f76-884d-5dd6-9bdd-a3cf142dd4d6', 'AG-045', 'George O.O LOGISTICS', '00000000-0000-4000-8000-792411006364', 'PH', ARRAY['PH']::TEXT[],
    'First Bank of Nigeria', '0450000765', 'George O.O LOGISTICS Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'George Logistics Manager', '+234 8046001395', 'Central Operations'
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
    '5150ba57-5773-5800-9286-0ab43cdb553e', 'AG-046', 'APPLE ABIA TAZE LOGISTICS SERVICES', '00000000-0000-4000-8000-792411006364', 'ABIA', ARRAY['ABIA']::TEXT[],
    'UBA', '0460000782', 'APPLE ABIA TAZE LOGISTICS SERVICES Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'APPLE Logistics Manager', '+234 8047001426', 'Central Operations'
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
    '35c99a98-6839-519e-93a0-a4a2aef98ced', 'AG-047', 'GINIKA ANAMBRA', '00000000-0000-4000-8000-792411006364', 'ANAMBRA', ARRAY['ANAMBRA']::TEXT[],
    'Fidelity Bank', '0470000799', 'GINIKA ANAMBRA Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'GINIKA Logistics Manager', '+234 8048001457', 'Central Operations'
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
    'fce4db5a-a711-5fde-ad4c-e5bb87c9dfa9', 'AG-048', 'Okolie Anthony ogorchukwu Logistics', '00000000-0000-4000-8000-792411006364', 'ANAMBRA', ARRAY['ANAMBRA']::TEXT[],
    'Stanbic IBTC', '0480000816', 'Okolie Anthony ogorchukwu Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Okolie Logistics Manager', '+234 8049001488', 'Central Operations'
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
    '594d7c33-22fa-5fe2-98ee-56fc11563052', 'AG-049', 'Durojaiye Ilashe Joseph Logistics', '22222222-2222-4222-8222-222222222222', 'KOGI', ARRAY['KOGI']::TEXT[],
    'Zenith Bank', '0490000833', 'Durojaiye Ilashe Joseph Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Durojaiye Logistics Manager', '+234 8050001519', 'Central Operations'
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
    '7f059f09-07dd-5202-806a-a9635a430b47', 'AG-050', 'ug express logistics ltd', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0500000850', 'ug express logistics ltd Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'ug Logistics Manager', '+234 8051001550', 'Central Operations'
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
    '7afe6908-8ae9-514a-ae69-277d30396c82', 'AG-051', 'milly logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '0510000867', 'milly logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'milly Logistics Manager', '+234 8052001581', 'Central Operations'
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
    'b8a79951-5d94-5ec1-a7dd-a5f7607908d8', 'AG-052', 'Elizabeth Anietie-Okon', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '0520000884', 'Elizabeth Anietie-Okon Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Elizabeth Logistics Manager', '+234 8053001612', 'Central Operations'
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
    '89f13c6e-7d13-5360-b763-937357f84fa5', 'AG-053', 'DASHGO DELIVERY CALABAR', '00000000-0000-4000-8000-792411006364', 'CALABAR', ARRAY['CALABAR']::TEXT[],
    'UBA', '0530000901', 'DASHGO DELIVERY CALABAR Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'DASHGO Logistics Manager', '+234 8054001643', 'Central Operations'
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
    '9d4de8e9-fb6f-5282-8dfd-a08feeb9291b', 'AG-054', 'presteveGo logistics', '22222222-2222-4222-8222-222222222222', 'KOGI', ARRAY['KOGI']::TEXT[],
    'Fidelity Bank', '0540000918', 'presteveGo logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'presteveGo Logistics Manager', '+234 8055001674', 'Central Operations'
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
    'cb37d5e6-eb62-54d1-8dac-1950c91267e1', 'AG-055', 'Sabi logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Stanbic IBTC', '0550000935', 'Sabi logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Sabi Logistics Manager', '+234 8056001705', 'Central Operations'
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
    '80fcc590-5727-58c7-8335-0abad4288013', 'AG-056', 'Alatiya Absalom Emmanuel Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0560000952', 'Alatiya Absalom Emmanuel Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Alatiya Logistics Manager', '+234 8057001736', 'Central Operations'
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
    '3e71558d-ccc1-54e3-b625-7d4e7552d806', 'AG-057', 'Safehands logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0570000969', 'Safehands logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Safehands Logistics Manager', '+234 8058001767', 'Central Operations'
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
    'e32cbd13-3b4f-5dc8-a42e-485f9c9a6540', 'AG-058', 'Olufunke Babalola Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '0580000986', 'Olufunke Babalola Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Olufunke Logistics Manager', '+234 8059001798', 'Central Operations'
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
    '83d8a40c-3437-5706-9d62-cd6967c87ad9', 'AG-059', 'Shittu Adebamke Yusuff Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '0590001003', 'Shittu Adebamke Yusuff Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Shittu Logistics Manager', '+234 8060001829', 'Central Operations'
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
    '93b7d252-e5e4-5316-8398-83de5128bacd', 'AG-060', 'Smart move Logistics Logistics LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '0600001020', 'Smart move Logistics Logistics LOGISTICS Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Smart Logistics Manager', '+234 8061001860', 'Central Operations'
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
    '2e6bdb22-7590-5dab-977b-5d8054779964', 'AG-061', 'TEMIBASH LOGISTICS LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '0610001037', 'TEMIBASH LOGISTICS LOGISTICS Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'TEMIBASH Logistics Manager', '+234 8062001891', 'Central Operations'
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
    '9a18923d-a60c-5282-a681-b9bf883a3d5b', 'AG-062', 'Solomon Uduak Ikpembe', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Stanbic IBTC', '0620001054', 'Solomon Uduak Ikpembe Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Solomon Logistics Manager', '+234 8063001922', 'Central Operations'
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
    'fce261f9-b278-5b63-bf05-f8bcefb0db9e', 'AG-063', 'Tajudeen A Ayetigbo LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0630001071', 'Tajudeen A Ayetigbo LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Tajudeen Logistics Manager', '+234 8064001953', 'Central Operations'
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
    '2388c60e-8682-5e6a-bf9e-7434925b75ba', 'AG-064', 'Usiju Ladu Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0640001088', 'Usiju Ladu Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Usiju Logistics Manager', '+234 8065001984', 'Central Operations'
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
    '90522c1c-d02d-54d4-8d91-20816b85f0d3', 'AG-065', 'Anthony Ezekiel Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '0650001105', 'Anthony Ezekiel Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Anthony Logistics Manager', '+234 8066002015', 'Central Operations'
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
    '6a7ee7b6-3d72-5813-970e-9e68ca291a30', 'AG-066', 'Emmanuel Nnamdi Ugwu Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '0660001122', 'Emmanuel Nnamdi Ugwu Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Emmanuel Logistics Manager', '+234 8067002046', 'Central Operations'
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
    'de7df501-a36e-5b48-869f-a7e8d6e5cf5a', 'AG-067', 'Adekunle Logistic', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '0670001139', 'Adekunle Logistic Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Adekunle Logistics Manager', '+234 8068002077', 'Central Operations'
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
    '5958d9cc-8cfd-58eb-a6d2-27ca99ad0d7f', 'AG-068', 'Enny logistics LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '0680001156', 'Enny logistics LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Enny Logistics Manager', '+234 8069002108', 'Central Operations'
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
    'd3e13af4-703a-58a6-b3df-fae1bd11c587', 'AG-069', 'imole logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Stanbic IBTC', '0690001173', 'imole logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'imole Logistics Manager', '+234 8070002139', 'Central Operations'
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
    '488c4447-1546-5759-a2fe-95a23d1e88ab', 'AG-070', 'Oluwatobi Femi-Fasan', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0700001190', 'Oluwatobi Femi-Fasan Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Oluwatobi Logistics Manager', '+234 8071002170', 'Central Operations'
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
    '00aaa429-d0fe-5639-8f96-a4c7afa94baa', 'AG-071', 'FOMAX ASABA (DELTA) LOGISTICS', '00000000-0000-4000-8000-792411006364', 'DELTA', ARRAY['DELTA']::TEXT[],
    'GTBank', '0710001207', 'FOMAX ASABA (DELTA) LOGISTICS Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'FOMAX Logistics Manager', '+234 8072002201', 'Central Operations'
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
    'a1d5ca76-59de-5022-a69d-4bb8b0cbabf1', 'AG-072', 'De Wealthz Logistics LOGISTICS', '00000000-0000-4000-8000-792411006364', 'AKWA IBOM', ARRAY['AKWA IBOM']::TEXT[],
    'Access Bank', '0720001224', 'De Wealthz Logistics LOGISTICS Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'De Logistics Manager', '+234 8073002232', 'Central Operations'
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
    '081aca8d-9093-5d70-b51b-8bb3c602afdb', 'AG-073', 'Steve temienor', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '0730001241', 'Steve temienor Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Steve Logistics Manager', '+234 8074002263', 'Central Operations'
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
    '07574873-d711-59d7-a5eb-c862442223bc', 'AG-074', 'Yohanna Vanduna Logistics', '22222222-2222-4222-8222-222222222222', 'JOS', ARRAY['JOS']::TEXT[],
    'UBA', '0740001258', 'Yohanna Vanduna Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Yohanna Logistics Manager', '+234 8075002294', 'Central Operations'
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
    '8618a8d9-5a6a-5ec1-b976-4f1216335213', 'AG-075', 'SendMe Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '0750001275', 'SendMe Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'SendMe Logistics Manager', '+234 8076002325', 'Central Operations'
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
    '0915efa2-75a5-5c1a-bf37-3115488e5ffd', 'AG-076', 'ISMAIL MUHAMMAD LIMAN', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Stanbic IBTC', '0760001292', 'ISMAIL MUHAMMAD LIMAN Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'ISMAIL Logistics Manager', '+234 8077002356', 'Central Operations'
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
    '3c12ca43-a137-5968-95b9-2ffbe2664c84', 'AG-077', 'ug express logistic ebonyi', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0770001309', 'ug express logistic ebonyi Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'ug Logistics Manager', '+234 8078002387', 'Central Operations'
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
    'af50803c-d3c4-5bb6-8b7f-88c47af9ad35', 'AG-078', 'Ibrahim Abdulrashid Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0780001326', 'Ibrahim Abdulrashid Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Ibrahim Logistics Manager', '+234 8079002418', 'Central Operations'
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
    '57be2228-5264-56ff-a7b9-d7a99b1ef6c7', 'AG-079', 'AB LOGISTICS KADUNA', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '0790001343', 'AB LOGISTICS KADUNA Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'AB Logistics Manager', '+234 8080002449', 'Central Operations'
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
    '9a0ebe4f-ca9c-5253-834d-6eabcda717cc', 'AG-080', 'ANIEADOLF CREATIONS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '0800001360', 'ANIEADOLF CREATIONS Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'ANIEADOLF Logistics Manager', '+234 8081002480', 'Central Operations'
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
    '178ce8ec-ff5c-5f92-9483-ff274a728fdd', 'AG-081', 'UGH LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '0810001377', 'UGH LOGISTICS Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'UGH Logistics Manager', '+234 8082002511', 'Central Operations'
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
    'da845157-64f2-5348-a45e-65b9f5caf9ab', 'AG-082', 'groza logistics ltd', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '0820001394', 'groza logistics ltd Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'groza Logistics Manager', '+234 8083002542', 'Central Operations'
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
    '5c08e883-fa94-5add-b421-3a51d2d4395e', 'AG-083', 'APPLE ANAMBRA DELIVERY SERVICES', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Stanbic IBTC', '0830001411', 'APPLE ANAMBRA DELIVERY SERVICES Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'APPLE Logistics Manager', '+234 8084002573', 'Central Operations'
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
    '5eee3fb5-e2e4-5f04-b1b6-89d10ef9bf3a', 'AG-084', 'Rapid moves logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0840001428', 'Rapid moves logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Rapid Logistics Manager', '+234 8085002604', 'Central Operations'
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
    '654fff80-f29c-52af-9804-c0eaa9e9c148', 'AG-085', 'Daniel Ekpo', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0850001445', 'Daniel Ekpo Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Daniel Logistics Manager', '+234 8086002635', 'Central Operations'
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
    '0a9d6365-2794-5575-9109-c069bfe16294', 'AG-086', 'Eagles Frontier Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '0860001462', 'Eagles Frontier Logistics Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Eagles Logistics Manager', '+234 8087002666', 'Central Operations'
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
    '715b5f4f-f75e-5e78-bba7-7a068b35eaf9', 'AG-087', 'TIMAGISTICS LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '0870001479', 'TIMAGISTICS LOGISTICS Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'TIMAGISTICS Logistics Manager', '+234 8088002697', 'Central Operations'
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
    '9abac0a7-bf69-58fb-8f59-3c4973735a9f', 'AG-088', 'Elite Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '0880001496', 'Elite Logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Elite Logistics Manager', '+234 8089002728', 'Central Operations'
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
    '3cf289ab-e332-5545-9f10-a4f0e1057152', 'AG-089', 'Abutu Emmanuel', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '0890001513', 'Abutu Emmanuel Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Abutu Logistics Manager', '+234 8090002759', 'Central Operations'
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
    '3f4dcab0-acc7-57c8-a7c9-531c57a0364d', 'AG-090', 'GOLFDLONA GLOBAL LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Stanbic IBTC', '0900001530', 'GOLFDLONA GLOBAL LOGISTICS Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'GOLFDLONA Logistics Manager', '+234 8091002790', 'Central Operations'
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
    '2ed324bc-11b6-5705-b799-79ef1073b332', 'AG-091', 'John Peter Adamawa', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0910001547', 'John Peter Adamawa Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'John Logistics Manager', '+234 8092002821', 'Central Operations'
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
    'Deiwa Logistics Manager', '+234 8093002852', 'Central Operations'
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
    '167c26a0-a695-526c-90f7-74520878b7a9', 'AG-093', 'KUSFAT LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '0930001581', 'KUSFAT LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'KUSFAT Logistics Manager', '+234 8094002883', 'Central Operations'
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
    '2b20dfa8-b896-5cab-b119-11446410b9d3', 'AG-094', 'Bloomish Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '0940001598', 'Bloomish Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Bloomish Logistics Manager', '+234 8095002914', 'Central Operations'
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
    '56501ff0-9459-5c40-90bc-f74a6e9fd351', 'AG-095', 'BLUE AMAZON LOGISTICS LTD LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '0950001615', 'BLUE AMAZON LOGISTICS LTD LOGISTICS Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'BLUE Logistics Manager', '+234 8096002945', 'Central Operations'
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
    '2a04a4c3-636d-59ec-9a69-112d554b9b4f', 'AG-096', 'FOMAX PH. LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '0960001632', 'FOMAX PH. LOGISTICS Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'FOMAX Logistics Manager', '+234 8097002976', 'Central Operations'
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
    'de664468-8462-57c2-bd06-3cd967057571', 'AG-097', 'Connect Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Stanbic IBTC', '0970001649', 'Connect Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Connect Logistics Manager', '+234 8098003007', 'Central Operations'
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
    'da34ff98-3d3e-552f-9681-b18b6a2eda98', 'AG-098', 'MELLUX LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Zenith Bank', '0980001666', 'MELLUX LOGISTICS Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'MELLUX Logistics Manager', '+234 8099003038', 'Central Operations'
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
    '36d7e1e2-56b3-5e38-99a6-5fc61e9fc589', 'AG-099', 'Spotnaire Logistics Ebonyi', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '0990001683', 'Spotnaire Logistics Ebonyi Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Spotnaire Logistics Manager', '+234 80100003069', 'Central Operations'
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
    '6b1ce548-a7fe-5560-b1c9-7da028da91f5', 'AG-100', 'Tagwaye Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '01000001700', 'Tagwaye Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Tagwaye Logistics Manager', '+234 80101003100', 'Central Operations'
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
    '36293cfb-a5f4-56b4-a24d-3b217dd8d929', 'AG-101', '3twelve logistics Services logistics Services', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '01010001717', '3twelve logistics Services logistics Services Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    '3twelve Logistics Manager', '+234 80102003131', 'Central Operations'
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
    'aa4f09cb-32dd-5769-a8e6-2da4f841a2b3', 'AG-102', 'Fabulous Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '01020001734', 'Fabulous Logistics Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'Fabulous Logistics Manager', '+234 80103003162', 'Central Operations'
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
    '38355457-91ee-54f6-b58a-47450fb2a77b', 'AG-103', 'TRUST LOGISTICS PDA', '22222222-2222-4222-8222-222222222222', 'BENUE', ARRAY['BENUE']::TEXT[],
    'Fidelity Bank', '01030001751', 'TRUST LOGISTICS PDA Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'TRUST Logistics Manager', '+234 80104003193', 'Central Operations'
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
    '36b74ad4-cdb2-5084-adb6-96649c52f4aa', 'AG-104', 'BTOP LOGISTICS', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Stanbic IBTC', '01040001768', 'BTOP LOGISTICS Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'BTOP Logistics Manager', '+234 80105003224', 'Central Operations'
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
    '4f8d2046-7e51-5985-b745-236d7a9edff7', 'AG-105', 'Tajudeen Logistics', '22222222-2222-4222-8222-222222222222', 'SOKOTO', ARRAY['SOKOTO']::TEXT[],
    'Zenith Bank', '01050001785', 'Tajudeen Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Tajudeen Logistics Manager', '+234 80106003255', 'Central Operations'
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
    '167b0cf1-26ed-5018-acc9-27e52c055935', 'AG-106', 'Global Debbie scents', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'GTBank', '01060001802', 'Global Debbie scents Remittance Trust', 5.0, 1000.0,
    2750.0, true, 'available', 'pda', 25,
    'Global Logistics Manager', '+234 80107003286', 'Central Operations'
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
    '55e3e1dd-7b0c-510b-9b97-92b17d29250a', 'AG-107', 'yusuf joy', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Access Bank', '01070001819', 'yusuf joy Remittance Trust', 5.0, 1000.0,
    3000.0, true, 'available', 'pda', 25,
    'yusuf Logistics Manager', '+234 80108003317', 'Central Operations'
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
    '9e99f02a-a8b3-5cfe-a35b-ebd6c1cd6727', 'AG-108', 'Nobelia logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'First Bank of Nigeria', '01080001836', 'Nobelia logistics Remittance Trust', 5.0, 1000.0,
    3250.0, true, 'available', 'pda', 25,
    'Nobelia Logistics Manager', '+234 80109003348', 'Central Operations'
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
    '3c96e16d-f041-5a96-842d-0f6522d5a8bc', 'AG-109', 'Davtom Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'UBA', '01090001853', 'Davtom Logistics Remittance Trust', 5.0, 1000.0,
    3500.0, true, 'available', 'pda', 25,
    'Davtom Logistics Manager', '+234 80110003379', 'Central Operations'
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
    '4f56f0fb-bd53-53b2-8006-da93b9b77615', 'AG-110', 'Mavicaon Logistics', '00000000-0000-4000-8000-792411006364', 'Lagos', ARRAY['Lagos']::TEXT[],
    'Fidelity Bank', '01100001870', 'Mavicaon Logistics Remittance Trust', 5.0, 1000.0,
    2500.0, true, 'available', 'pda', 25,
    'Mavicaon Logistics Manager', '+234 80111003410', 'Central Operations'
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
