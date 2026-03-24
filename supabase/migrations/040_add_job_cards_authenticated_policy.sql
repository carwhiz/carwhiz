-- Migration 040: Add authenticated role policies for job_cards tables
-- Purpose: Allow authenticated users to access job card data
-- Previously only anon and service_role had policies

-- Add authenticated policy for job_cards
DROP POLICY IF EXISTS jc_authenticated ON public.job_cards;
CREATE POLICY jc_authenticated ON public.job_cards 
  FOR ALL TO authenticated 
  USING (true) WITH CHECK (true);

-- Add authenticated policy for job_card_items
DROP POLICY IF EXISTS jci_authenticated ON public.job_card_items;
CREATE POLICY jci_authenticated ON public.job_card_items 
  FOR ALL TO authenticated 
  USING (true) WITH CHECK (true);

-- Add authenticated policy for job_card_photos
DROP POLICY IF EXISTS jcp_authenticated ON public.job_card_photos;
CREATE POLICY jcp_authenticated ON public.job_card_photos 
  FOR ALL TO authenticated 
  USING (true) WITH CHECK (true);

-- Add authenticated policy for job_card_notes
DROP POLICY IF EXISTS jcn_authenticated ON public.job_card_notes;
CREATE POLICY jcn_authenticated ON public.job_card_notes 
  FOR ALL TO authenticated 
  USING (true) WITH CHECK (true);

-- Add authenticated policy for job_card_logs
DROP POLICY IF EXISTS jcl_authenticated ON public.job_card_logs;
CREATE POLICY jcl_authenticated ON public.job_card_logs 
  FOR ALL TO authenticated 
  USING (true) WITH CHECK (true);
