-- PART 1: Tables only (no function)
CREATE SEQUENCE IF NOT EXISTS public.job_card_seq START 1;

CREATE TABLE IF NOT EXISTS public.job_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_card_no TEXT NOT NULL UNIQUE,
  customer_id UUID NOT NULL REFERENCES public.customers(id),
  vehicle_id UUID NOT NULL REFERENCES public.vehicles(id),
  assigned_user_id UUID NOT NULL REFERENCES public.users(id),
  status TEXT NOT NULL DEFAULT 'Open' CHECK (status IN ('Open','In Progress','Closed','Billed','Cancelled')),
  priority TEXT DEFAULT 'Normal' CHECK (priority IN ('Low','Normal','High','Urgent')),
  description TEXT NOT NULL,
  details TEXT,
  expected_date DATE,
  closed_by UUID REFERENCES public.users(id),
  closed_at TIMESTAMPTZ,
  billed_invoice_id UUID REFERENCES public.sales(id),
  billed_at TIMESTAMPTZ,
  created_by UUID REFERENCES public.users(id),
  updated_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.job_cards ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS jc_anon_full ON public.job_cards;
CREATE POLICY jc_anon_full ON public.job_cards FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS jc_service_full ON public.job_cards;
CREATE POLICY jc_service_full ON public.job_cards FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.job_card_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_card_id UUID NOT NULL REFERENCES public.job_cards(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL CHECK (item_type IN ('product','service','consumable')),
  item_id UUID REFERENCES public.products(id),
  name TEXT NOT NULL,
  qty NUMERIC(14,3) DEFAULT 1,
  price NUMERIC(14,2) DEFAULT 0,
  discount NUMERIC(14,2) DEFAULT 0,
  total NUMERIC(14,2) DEFAULT 0,
  notes TEXT,
  created_by UUID REFERENCES public.users(id),
  updated_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.job_card_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS jci_anon_full ON public.job_card_items;
CREATE POLICY jci_anon_full ON public.job_card_items FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS jci_service_full ON public.job_card_items;
CREATE POLICY jci_service_full ON public.job_card_items FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.job_card_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_card_id UUID NOT NULL REFERENCES public.job_cards(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  file_name TEXT,
  uploaded_by UUID REFERENCES public.users(id),
  created_by UUID REFERENCES public.users(id),
  updated_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.job_card_photos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS jcp_anon_full ON public.job_card_photos;
CREATE POLICY jcp_anon_full ON public.job_card_photos FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS jcp_service_full ON public.job_card_photos;
CREATE POLICY jcp_service_full ON public.job_card_photos FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.job_card_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_card_id UUID NOT NULL REFERENCES public.job_cards(id) ON DELETE CASCADE,
  note TEXT NOT NULL,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.job_card_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS jcn_anon_full ON public.job_card_notes;
CREATE POLICY jcn_anon_full ON public.job_card_notes FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS jcn_service_full ON public.job_card_notes;
CREATE POLICY jcn_service_full ON public.job_card_notes FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.job_card_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_card_id UUID NOT NULL REFERENCES public.job_cards(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  from_status TEXT,
  to_status TEXT,
  note TEXT,
  action_by UUID REFERENCES public.users(id),
  created_by UUID REFERENCES public.users(id),
  updated_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.job_card_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS jcl_anon_full ON public.job_card_logs;
CREATE POLICY jcl_anon_full ON public.job_card_logs FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS jcl_service_full ON public.job_card_logs;
CREATE POLICY jcl_service_full ON public.job_card_logs FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS trg_audit_job_cards ON public.job_cards;
CREATE TRIGGER trg_audit_job_cards AFTER INSERT OR UPDATE OR DELETE ON public.job_cards FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
DROP TRIGGER IF EXISTS trg_audit_job_card_items ON public.job_card_items;
CREATE TRIGGER trg_audit_job_card_items AFTER INSERT OR UPDATE OR DELETE ON public.job_card_items FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
DROP TRIGGER IF EXISTS trg_audit_job_card_photos ON public.job_card_photos;
CREATE TRIGGER trg_audit_job_card_photos AFTER INSERT OR UPDATE OR DELETE ON public.job_card_photos FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
DROP TRIGGER IF EXISTS trg_audit_job_card_notes ON public.job_card_notes;
CREATE TRIGGER trg_audit_job_card_notes AFTER INSERT OR UPDATE OR DELETE ON public.job_card_notes FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();
DROP TRIGGER IF EXISTS trg_audit_job_card_logs ON public.job_card_logs;
CREATE TRIGGER trg_audit_job_card_logs AFTER INSERT OR UPDATE OR DELETE ON public.job_card_logs FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();

INSERT INTO storage.buckets (id, name, public) VALUES ('job-card-photos', 'job-card-photos', true) ON CONFLICT (id) DO NOTHING;
DROP POLICY IF EXISTS "job_card_photos_public_read" ON storage.objects;
CREATE POLICY "job_card_photos_public_read" ON storage.objects FOR SELECT USING (bucket_id = 'job-card-photos');
DROP POLICY IF EXISTS "job_card_photos_public_insert" ON storage.objects;
CREATE POLICY "job_card_photos_public_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'job-card-photos');
DROP POLICY IF EXISTS "job_card_photos_public_delete" ON storage.objects;
CREATE POLICY "job_card_photos_public_delete" ON storage.objects FOR DELETE USING (bucket_id = 'job-card-photos');
