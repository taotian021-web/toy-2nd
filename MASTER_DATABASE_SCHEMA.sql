-- ============================================================================
-- SWAPNORGE MASTER PRODUCTION DATABASE SCHEMA, STORAGE & RLS MIGRATION
-- Migration Timestamp: 2026-09-29
-- ============================================================================
-- Complete 13-Table Unified Architecture:
-- 1. profiles              (User profiles, reputation, karma points, dual-casing columns)
-- 2. items                 (Secondhand exchange listings, category, coordinates, status)
-- 3. "swapRequests"        (Direct peer-to-peer exchange agreements & trade chat)
-- 4. products              (Community group-buy offers & local service deals)
-- 5. favorites             (Saved items & wishlists per user)
-- 6. transactions          (Immutable audit ledger for Bokføringsloven § 13 compliance)
-- 7. reviews               (Peer ratings & completion reviews)
-- 8. feedback              (Beta user feedback, bug reports & system logs)
-- 9. partner_vouchers      (Merchant voucher perks library & live inventory)
-- 10. voucher_redemptions  (Merchant redemption receipts & cashier validation)
-- 11. neighbor_wishes      (Neighborhood bounty requests & community asks)
-- 12. disputes             (Trade dispute cases, evidence & admin arbitration)
-- 13. reports              (Content compliance & community whistleblowing)
--
-- Storage Buckets & Policies:
-- - items, images, avatars, videos, swapRequests
-- ============================================================================

-- ============================================================================
-- 0. SYSTEM EXTENSIONS & CONFIGURATION
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. STORAGE BUCKET INITIALIZATION
-- ============================================================================
-- Ensure all application storage buckets are initialized and public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('items', 'items', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('images', 'images', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('avatars', 'avatars', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('videos', 'videos', true, 104857600, ARRAY['video/mp4', 'video/quicktime', 'video/webm']),
  ('swapRequests', 'swapRequests', true, 52428800, NULL)
ON CONFLICT (id) DO UPDATE SET 
  public = EXCLUDED.public;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Storage RLS Policies
DROP POLICY IF EXISTS "Public storage read" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated storage upload" ON storage.objects;
DROP POLICY IF EXISTS "Owner storage update" ON storage.objects;
DROP POLICY IF EXISTS "Owner storage delete" ON storage.objects;

-- Allow anyone to read public bucket assets
CREATE POLICY "Public storage read" ON storage.objects
  FOR SELECT USING (bucket_id IN ('items', 'images', 'avatars', 'videos', 'swapRequests'));

-- Allow authenticated users to upload files to public buckets
CREATE POLICY "Authenticated storage upload" ON storage.objects
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' 
    AND bucket_id IN ('items', 'images', 'avatars', 'videos', 'swapRequests')
  );

-- Allow owners to update their uploaded objects
CREATE POLICY "Owner storage update" ON storage.objects
  FOR UPDATE USING (
    auth.role() = 'authenticated' 
    AND (
      auth.uid()::text = (storage.foldername(name))[1] 
      OR auth.uid()::text = owner::text
      OR auth.role() = 'service_role'
    )
  );

-- Allow owners to delete their uploaded objects
CREATE POLICY "Owner storage delete" ON storage.objects
  FOR DELETE USING (
    auth.role() = 'authenticated' 
    AND (
      auth.uid()::text = (storage.foldername(name))[1] 
      OR auth.uid()::text = owner::text
      OR auth.role() = 'service_role'
    )
  );

-- ============================================================================
-- 2. APPLICATION CORE TABLES
-- ============================================================================

-- Table 1: PROFILES
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  uid TEXT NOT NULL,
  display_name TEXT,
  "displayName" TEXT,
  photo_url TEXT,
  "photoURL" TEXT,
  avatar_url TEXT,
  "avatarUrl" TEXT,
  stats JSONB DEFAULT '{"points": 100, "reputation": 5.0, "completedSwaps": 0, "memberSince": null}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "displayName" TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "photoURL" TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "avatar_url" TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "avatarUrl" TEXT;

-- Table 2: ITEMS
CREATE TABLE IF NOT EXISTS public.items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  points INTEGER NOT NULL DEFAULT 0 CHECK (points >= 0),
  category TEXT NOT NULL,
  condition TEXT,
  "imageUrl" TEXT,
  "sellerId" TEXT NOT NULL,
  "sellerName" TEXT NOT NULL,
  "sellerRating" NUMERIC DEFAULT 5.0 CHECK ("sellerRating" >= 1.0 AND "sellerRating" <= 5.0),
  "postedDate" TEXT NOT NULL,
  "isPublic" BOOLEAN DEFAULT true,
  location JSONB DEFAULT '{"latitude": 59.9111, "longitude": 10.7528, "city": "Oslo"}'::jsonb,
  status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'pending', 'completed', 'reserved')),
  views INTEGER DEFAULT 0 CHECK (views >= 0),
  likes INTEGER DEFAULT 0 CHECK (likes >= 0),
  "videoUrls" JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 3: SWAP REQUESTS
CREATE TABLE IF NOT EXISTS public."swapRequests" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "itemId" TEXT NOT NULL,
  "itemTitle" TEXT NOT NULL,
  "itemImageUrl" TEXT,
  message TEXT,
  points INTEGER NOT NULL DEFAULT 0 CHECK (points >= 0),
  "senderId" TEXT NOT NULL,
  "senderName" TEXT NOT NULL,
  "receiverId" TEXT NOT NULL,
  "receiverName" TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled', 'completed', 'expired')),
  "createdAt" TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 4: PRODUCTS (Community Group-buys & Deals)
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC NOT NULL DEFAULT 0 CHECK (price >= 0),
  category TEXT NOT NULL,
  "sellerId" TEXT NOT NULL,
  "postedDate" TEXT NOT NULL,
  "isPublic" BOOLEAN DEFAULT true,
  location JSONB,
  urgency TEXT NOT NULL DEFAULT 'normal' CHECK (urgency IN ('low', 'normal', 'high', 'urgent')),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'completed')),
  responses INTEGER DEFAULT 0 CHECK (responses >= 0),
  likes INTEGER DEFAULT 0 CHECK (likes >= 0),
  views INTEGER DEFAULT 0 CHECK (views >= 0),
  "createdAt" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "storeName" TEXT,
  "validUntil" TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 5: FAVORITES
CREATE TABLE IF NOT EXISTS public.favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId" TEXT NOT NULL,
  "itemId" TEXT NOT NULL,
  "savedAt" TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 6: TRANSACTIONS (Bokføringsloven § 13 Compliant Immutable Ledger)
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId" TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('earn', 'spend', 'admin_adjustment', 'swap_bonus', 'swap_payment', 'swap_refund', 'registration_bonus')),
  amount INTEGER NOT NULL,
  "targetId" TEXT,
  "targetName" TEXT,
  "itemId" TEXT,
  "itemTitle" TEXT,
  "createdAt" TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 7: REVIEWS
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "fromId" TEXT NOT NULL,
  "fromName" TEXT NOT NULL,
  "toId" TEXT NOT NULL,
  "requestId" TEXT NOT NULL,
  content TEXT NOT NULL,
  rating NUMERIC NOT NULL CHECK (rating >= 1.0 AND rating <= 5.0),
  "createdAt" TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 8: FEEDBACK (Beta User Feedback & System Reports)
CREATE TABLE IF NOT EXISTS public.feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id TEXT NOT NULL,
  user_id TEXT NOT NULL DEFAULT 'anonymous',
  user_email TEXT NOT NULL,
  type TEXT NOT NULL,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  content TEXT NOT NULL,
  system_info JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 9: PARTNER VOUCHERS
CREATE TABLE IF NOT EXISTS public.partner_vouchers (
  id TEXT PRIMARY KEY,
  partner_name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('coffee', 'bakery', 'groceries', 'sports', 'other')),
  title TEXT NOT NULL,
  description TEXT,
  points_cost INTEGER NOT NULL CHECK (points_cost >= 0),
  real_value_nok INTEGER NOT NULL CHECK (real_value_nok >= 0),
  stock_total INTEGER NOT NULL DEFAULT 100,
  stock_remaining INTEGER NOT NULL DEFAULT 100,
  is_active BOOLEAN NOT NULL DEFAULT true,
  logo_emoji TEXT DEFAULT '🎁',
  image_url TEXT,
  valid_days INTEGER DEFAULT 30,
  terms TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Table 10: VOUCHER REDEMPTIONS
CREATE TABLE IF NOT EXISTS public.voucher_redemptions (
  id TEXT PRIMARY KEY,
  voucher_id TEXT NOT NULL REFERENCES public.partner_vouchers(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL,
  partner_name TEXT NOT NULL,
  title TEXT NOT NULL,
  points_cost INTEGER NOT NULL,
  real_value_nok INTEGER NOT NULL,
  is_used BOOLEAN NOT NULL DEFAULT false,
  redeemed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  used_at TIMESTAMPTZ,
  used_by_merchant TEXT,
  expires_at TIMESTAMPTZ NOT NULL
);

-- Table 11: NEIGHBOR WISHES
CREATE TABLE IF NOT EXISTS public.neighbor_wishes (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL DEFAULT 'Hjem',
  hub_id TEXT,
  author_id TEXT NOT NULL,
  author_name TEXT NOT NULL,
  author_avatar TEXT,
  bounty_points INTEGER NOT NULL DEFAULT 50,
  pickup_preference TEXT NOT NULL DEFAULT 'doormat' CHECK (pickup_preference IN ('doormat', 'meetup', 'locker')),
  urgency TEXT NOT NULL DEFAULT 'normal' CHECK (urgency IN ('normal', 'urgent')),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'fulfilled', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Table 12: DISPUTES
CREATE TABLE IF NOT EXISTS public.disputes (
  id TEXT PRIMARY KEY,
  swap_request_id TEXT NOT NULL,
  item_title TEXT,
  item_points INTEGER DEFAULT 150,
  item_image_url TEXT,
  complainant_id TEXT NOT NULL,
  complainant_name TEXT,
  complainant_statement TEXT,
  respondent_id TEXT NOT NULL,
  respondent_name TEXT,
  respondent_statement TEXT,
  meetup_location TEXT,
  pickup_method TEXT,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'resolved_refund', 'resolved_dismissed', 'resolved_mutual')),
  resolution_summary TEXT,
  refund_points_amount INTEGER DEFAULT 0,
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  resolved_at TIMESTAMPTZ
);

-- Table 13: REPORTS
CREATE TABLE IF NOT EXISTS public.reports (
  id TEXT PRIMARY KEY,
  reporter_id TEXT NOT NULL,
  reporter_name TEXT NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('item', 'user', 'swap')),
  target_id TEXT NOT NULL,
  target_title TEXT,
  target_owner_name TEXT,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'dismissed')),
  action_taken TEXT,
  reward_points_granted INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  resolved_at TIMESTAMPTZ,
  resolved_by TEXT
);

-- ============================================================================
-- 3. HIGH-PERFORMANCE B-TREE DATABASE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_profiles_uid ON public.profiles(uid);
CREATE INDEX IF NOT EXISTS idx_items_seller_id ON public.items("sellerId");
CREATE INDEX IF NOT EXISTS idx_items_status ON public.items(status);
CREATE INDEX IF NOT EXISTS idx_items_is_public ON public.items("isPublic");
CREATE INDEX IF NOT EXISTS idx_swap_requests_sender_id ON public."swapRequests"("senderId");
CREATE INDEX IF NOT EXISTS idx_swap_requests_receiver_id ON public."swapRequests"("receiverId");
CREATE INDEX IF NOT EXISTS idx_swap_requests_status ON public."swapRequests"(status);
CREATE INDEX IF NOT EXISTS idx_products_user_id ON public.products("userId");
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON public.favorites("userId");
CREATE INDEX IF NOT EXISTS idx_favorites_item_id ON public.favorites("itemId");
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions("userId");
CREATE INDEX IF NOT EXISTS idx_reviews_to_id ON public.reviews("toId");
CREATE INDEX IF NOT EXISTS idx_feedback_ticket_id ON public.feedback(ticket_id);
CREATE INDEX IF NOT EXISTS idx_feedback_created ON public.feedback(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_partner_vouchers_active ON public.partner_vouchers(is_active, category);
CREATE INDEX IF NOT EXISTS idx_voucher_redemptions_code ON public.voucher_redemptions(code);
CREATE INDEX IF NOT EXISTS idx_voucher_redemptions_user ON public.voucher_redemptions(user_id, is_used);
CREATE INDEX IF NOT EXISTS idx_neighbor_wishes_hub ON public.neighbor_wishes(hub_id, status);
CREATE INDEX IF NOT EXISTS idx_disputes_status ON public.disputes(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status, created_at DESC);

-- ============================================================================
-- 4. REALTIME PUBLICATION SETUP
-- ============================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.items;
    ALTER PUBLICATION supabase_realtime ADD TABLE public."swapRequests";
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.partner_vouchers;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.voucher_redemptions;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.neighbor_wishes;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.disputes;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.reports;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- ============================================================================
-- 5. TRIGGERS & PROCEDURES
-- ============================================================================

-- Trigger 1: Automatic User Profile Creation on Signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  initial_name TEXT;
  initial_avatar TEXT;
  member_date TEXT;
BEGIN
  initial_name := coalesce(
    new.raw_user_meta_data->>'full_name', 
    new.raw_user_meta_data->>'display_name', 
    split_part(new.email, '@', 1), 
    'Nabolagsvenn'
  );
  
  initial_avatar := coalesce(
    new.raw_user_meta_data->>'avatar_url', 
    new.raw_user_meta_data->>'photo_url', 
    'https://i.pravatar.cc/150?u=' || new.id
  );

  member_date := to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS"Z"');

  INSERT INTO public.profiles (
    id, 
    uid, 
    display_name, 
    "displayName", 
    photo_url, 
    "photoURL", 
    avatar_url, 
    "avatarUrl", 
    stats, 
    created_at, 
    updated_at
  )
  VALUES (
    new.id,
    new.id::text,
    initial_name,
    initial_name,
    initial_avatar,
    initial_avatar,
    initial_avatar,
    initial_avatar,
    jsonb_build_object(
      'points', 100,
      'reputation', 5.0,
      'completedSwaps', 0,
      'memberSince', member_date
    ),
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    uid = EXCLUDED.uid,
    display_name = coalesce(profiles.display_name, EXCLUDED.display_name),
    "displayName" = coalesce(profiles."displayName", EXCLUDED."displayName"),
    photo_url = coalesce(profiles.photo_url, EXCLUDED.photo_url),
    "photoURL" = coalesce(profiles."photoURL", EXCLUDED."photoURL");
    
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger 2: Column synchronization (camelCase <=> snake_case)
CREATE OR REPLACE FUNCTION public.sync_profile_columns()
RETURNS trigger AS $$
BEGIN
  IF new.display_name IS NOT NULL AND new."displayName" IS NULL THEN
    new."displayName" := new.display_name;
  ELSIF new."displayName" IS NOT NULL AND new.display_name IS NULL THEN
    new.display_name := new."displayName";
  END IF;

  IF new.photo_url IS NOT NULL THEN
    new."photoURL" := coalesce(new."photoURL", new.photo_url);
    new.avatar_url := coalesce(new.avatar_url, new.photo_url);
    new."avatarUrl" := coalesce(new."avatarUrl", new.photo_url);
  ELSIF new."photoURL" IS NOT NULL THEN
    new.photo_url := new."photoURL";
    new.avatar_url := coalesce(new.avatar_url, new."photoURL");
    new."avatarUrl" := coalesce(new."avatarUrl", new."photoURL");
  END IF;

  new.updated_at := NOW();
  RETURN new;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_profile_columns ON public.profiles;
CREATE TRIGGER trg_sync_profile_columns
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_profile_columns();

-- Trigger 3: GDPR Deletion & Bokføringsloven Audit Protection
CREATE OR REPLACE FUNCTION public.handle_gdpr_user_deletion()
RETURNS trigger AS $$
BEGIN
  UPDATE public.reviews 
  SET "fromName" = 'Slettet bruker'
  WHERE "fromId" = old.id::text;

  DELETE FROM public.items 
  WHERE "sellerId" = old.id::text AND status != 'completed';

  UPDATE public.items 
  SET "sellerName" = 'Slettet bruker', "sellerId" = 'deleted'
  WHERE "sellerId" = old.id::text AND status = 'completed';

  DELETE FROM public.favorites WHERE "userId" = old.id::text;

  DELETE FROM public.products 
  WHERE "sellerId" = old.id::text OR "userId" = old.id::text;

  DELETE FROM public.profiles WHERE id = old.id;

  RETURN old;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_deleted ON auth.users;
CREATE TRIGGER on_auth_user_deleted
  BEFORE DELETE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_gdpr_user_deletion();

ALTER TABLE public.items ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public."swapRequests" ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public."swapRequests" ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Trigger 4: Automatic timestamp refresh (defensive)
CREATE OR REPLACE FUNCTION public.update_modified_column()
RETURNS trigger AS $$
BEGIN
  BEGIN
    IF to_jsonb(new) ? 'updated_at' THEN
      new.updated_at := NOW();
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  RETURN new;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_items_modified ON public.items;
CREATE TRIGGER trg_update_items_modified BEFORE UPDATE ON public.items FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();

DROP TRIGGER IF EXISTS trg_update_swap_requests_modified ON public."swapRequests";
CREATE TRIGGER trg_update_swap_requests_modified BEFORE UPDATE ON public."swapRequests" FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();

DROP TRIGGER IF EXISTS trg_update_products_modified ON public.products;
CREATE TRIGGER trg_update_products_modified BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();

-- ============================================================================
-- 6. HARDENED PRODUCTION ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS across all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."swapRequests" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voucher_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.neighbor_wishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- PROFILES POLICIES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;

CREATE POLICY "profiles_select_policy" ON public.profiles 
  FOR SELECT USING (true);

CREATE POLICY "profiles_insert_policy" ON public.profiles 
  FOR INSERT WITH CHECK (id = auth.uid() OR auth.role() = 'service_role');

CREATE POLICY "profiles_update_policy" ON public.profiles 
  FOR UPDATE USING (id = auth.uid() OR auth.role() = 'service_role')
  WITH CHECK (id = auth.uid() OR auth.role() = 'service_role');

-- ----------------------------------------------------------------------------
-- ITEMS POLICIES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "items_select_policy" ON public.items;
DROP POLICY IF EXISTS "items_insert_policy" ON public.items;
DROP POLICY IF EXISTS "items_update_policy" ON public.items;
DROP POLICY IF EXISTS "items_delete_policy" ON public.items;

CREATE POLICY "items_select_policy" ON public.items 
  FOR SELECT USING (true);

CREATE POLICY "items_insert_policy" ON public.items 
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND "sellerId" = auth.uid()::text
    )
  );

CREATE POLICY "items_update_policy" ON public.items 
  FOR UPDATE USING (
    auth.role() = 'service_role' OR "sellerId" = auth.uid()::text
  )
  WITH CHECK (
    auth.role() = 'service_role' OR "sellerId" = auth.uid()::text
  );

CREATE POLICY "items_delete_policy" ON public.items 
  FOR DELETE USING (
    auth.role() = 'service_role' OR "sellerId" = auth.uid()::text
  );

-- ----------------------------------------------------------------------------
-- SWAP REQUESTS POLICIES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "swap_requests_select_policy" ON public."swapRequests";
DROP POLICY IF EXISTS "swap_requests_insert_policy" ON public."swapRequests";
DROP POLICY IF EXISTS "swap_requests_update_policy" ON public."swapRequests";
DROP POLICY IF EXISTS "swap_requests_delete_policy" ON public."swapRequests";

CREATE POLICY "swap_requests_select_policy" ON public."swapRequests" 
  FOR SELECT USING (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND (
        "senderId" = auth.uid()::text OR "receiverId" = auth.uid()::text
      )
    )
  );

CREATE POLICY "swap_requests_insert_policy" ON public."swapRequests" 
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND "senderId" = auth.uid()::text
    )
  );

CREATE POLICY "swap_requests_update_policy" ON public."swapRequests" 
  FOR UPDATE USING (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND (
        "senderId" = auth.uid()::text OR "receiverId" = auth.uid()::text
      )
    )
  );

CREATE POLICY "swap_requests_delete_policy" ON public."swapRequests" 
  FOR DELETE USING (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND "senderId" = auth.uid()::text
    )
  );

-- ----------------------------------------------------------------------------
-- PRODUCTS POLICIES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "products_select_policy" ON public.products;
DROP POLICY IF EXISTS "products_insert_policy" ON public.products;
DROP POLICY IF EXISTS "products_update_policy" ON public.products;
DROP POLICY IF EXISTS "products_delete_policy" ON public.products;

CREATE POLICY "products_select_policy" ON public.products 
  FOR SELECT USING (true);

CREATE POLICY "products_insert_policy" ON public.products 
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND "userId" = auth.uid()::text
    )
  );

CREATE POLICY "products_update_policy" ON public.products 
  FOR UPDATE USING (
    auth.role() = 'service_role' OR "userId" = auth.uid()::text
  );

CREATE POLICY "products_delete_policy" ON public.products 
  FOR DELETE USING (
    auth.role() = 'service_role' OR "userId" = auth.uid()::text
  );

-- ----------------------------------------------------------------------------
-- FAVORITES POLICIES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "favorites_select_policy" ON public.favorites;
DROP POLICY IF EXISTS "favorites_insert_policy" ON public.favorites;
DROP POLICY IF EXISTS "favorites_delete_policy" ON public.favorites;

CREATE POLICY "favorites_select_policy" ON public.favorites 
  FOR SELECT USING (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND "userId" = auth.uid()::text
    )
  );

CREATE POLICY "favorites_insert_policy" ON public.favorites 
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND "userId" = auth.uid()::text
    )
  );

CREATE POLICY "favorites_delete_policy" ON public.favorites 
  FOR DELETE USING (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND "userId" = auth.uid()::text
    )
  );

-- ----------------------------------------------------------------------------
-- TRANSACTIONS POLICIES (Bokføringsloven § 13: Strictly Read & Insert Only)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "transactions_select_policy" ON public.transactions;
DROP POLICY IF EXISTS "transactions_insert_policy" ON public.transactions;

CREATE POLICY "transactions_select_policy" ON public.transactions 
  FOR SELECT USING (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND "userId" = auth.uid()::text
    )
  );

CREATE POLICY "transactions_insert_policy" ON public.transactions 
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND "userId" = auth.uid()::text
    )
  );

-- ----------------------------------------------------------------------------
-- REVIEWS POLICIES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "reviews_select_policy" ON public.reviews;
DROP POLICY IF EXISTS "reviews_insert_policy" ON public.reviews;
DROP POLICY IF EXISTS "reviews_delete_policy" ON public.reviews;

CREATE POLICY "reviews_select_policy" ON public.reviews 
  FOR SELECT USING (true);

CREATE POLICY "reviews_insert_policy" ON public.reviews 
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND "fromId" = auth.uid()::text
    )
  );

CREATE POLICY "reviews_delete_policy" ON public.reviews 
  FOR DELETE USING (
    auth.role() = 'service_role' OR (
      auth.role() = 'authenticated' AND "fromId" = auth.uid()::text
    )
  );

-- ----------------------------------------------------------------------------
-- FEEDBACK POLICIES (Open submission for beta users, admin review)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "feedback_insert_policy" ON public.feedback;
DROP POLICY IF EXISTS "feedback_select_policy" ON public.feedback;

CREATE POLICY "feedback_insert_policy" ON public.feedback 
  FOR INSERT WITH CHECK (true);

CREATE POLICY "feedback_select_policy" ON public.feedback 
  FOR SELECT USING (
    auth.role() = 'service_role' 
    OR (auth.role() = 'authenticated' AND (user_id = auth.uid()::text OR auth.jwt() ->> 'email' LIKE '%@swapnorge.no'))
  );

-- ----------------------------------------------------------------------------
-- PARTNER VOUCHERS POLICIES (Public read, Admin/Service-Role write)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public read partner_vouchers" ON public.partner_vouchers;
DROP POLICY IF EXISTS "Public insert partner_vouchers" ON public.partner_vouchers;
DROP POLICY IF EXISTS "Public update partner_vouchers" ON public.partner_vouchers;
DROP POLICY IF EXISTS "partner_vouchers_select_policy" ON public.partner_vouchers;
DROP POLICY IF EXISTS "partner_vouchers_insert_policy" ON public.partner_vouchers;
DROP POLICY IF EXISTS "partner_vouchers_update_policy" ON public.partner_vouchers;
DROP POLICY IF EXISTS "partner_vouchers_delete_policy" ON public.partner_vouchers;

CREATE POLICY "partner_vouchers_select_policy" ON public.partner_vouchers 
  FOR SELECT USING (true);

CREATE POLICY "partner_vouchers_insert_policy" ON public.partner_vouchers 
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' 
    OR (auth.role() = 'authenticated' AND auth.jwt() ->> 'email' LIKE '%@swapnorge.no')
  );

CREATE POLICY "partner_vouchers_update_policy" ON public.partner_vouchers 
  FOR UPDATE USING (
    auth.role() = 'service_role' 
    OR (auth.role() = 'authenticated' AND auth.jwt() ->> 'email' LIKE '%@swapnorge.no')
  );

CREATE POLICY "partner_vouchers_delete_policy" ON public.partner_vouchers 
  FOR DELETE USING (
    auth.role() = 'service_role' 
    OR (auth.role() = 'authenticated' AND auth.jwt() ->> 'email' LIKE '%@swapnorge.no')
  );

-- ----------------------------------------------------------------------------
-- VOUCHER REDEMPTIONS POLICIES (User own redemption or merchant validation)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public read voucher_redemptions" ON public.voucher_redemptions;
DROP POLICY IF EXISTS "Public insert voucher_redemptions" ON public.voucher_redemptions;
DROP POLICY IF EXISTS "Public update voucher_redemptions" ON public.voucher_redemptions;
DROP POLICY IF EXISTS "voucher_redemptions_select_policy" ON public.voucher_redemptions;
DROP POLICY IF EXISTS "voucher_redemptions_insert_policy" ON public.voucher_redemptions;
DROP POLICY IF EXISTS "voucher_redemptions_update_policy" ON public.voucher_redemptions;

CREATE POLICY "voucher_redemptions_select_policy" ON public.voucher_redemptions 
  FOR SELECT USING (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND (
        user_id = auth.uid()::text 
        OR auth.jwt() ->> 'email' LIKE '%@swapnorge.no'
      )
    )
  );

CREATE POLICY "voucher_redemptions_insert_policy" ON public.voucher_redemptions 
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND user_id = auth.uid()::text
    )
  );

CREATE POLICY "voucher_redemptions_update_policy" ON public.voucher_redemptions 
  FOR UPDATE USING (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND (
        user_id = auth.uid()::text 
        OR auth.jwt() ->> 'email' LIKE '%@swapnorge.no'
      )
    )
  );

-- ----------------------------------------------------------------------------
-- NEIGHBOR WISHES POLICIES (Public read, author manage)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public read neighbor_wishes" ON public.neighbor_wishes;
DROP POLICY IF EXISTS "Public insert neighbor_wishes" ON public.neighbor_wishes;
DROP POLICY IF EXISTS "Public update neighbor_wishes" ON public.neighbor_wishes;
DROP POLICY IF EXISTS "neighbor_wishes_select_policy" ON public.neighbor_wishes;
DROP POLICY IF EXISTS "neighbor_wishes_insert_policy" ON public.neighbor_wishes;
DROP POLICY IF EXISTS "neighbor_wishes_update_policy" ON public.neighbor_wishes;
DROP POLICY IF EXISTS "neighbor_wishes_delete_policy" ON public.neighbor_wishes;

CREATE POLICY "neighbor_wishes_select_policy" ON public.neighbor_wishes 
  FOR SELECT USING (true);

CREATE POLICY "neighbor_wishes_insert_policy" ON public.neighbor_wishes 
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND author_id = auth.uid()::text
    )
  );

CREATE POLICY "neighbor_wishes_update_policy" ON public.neighbor_wishes 
  FOR UPDATE USING (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND author_id = auth.uid()::text
    )
  );

CREATE POLICY "neighbor_wishes_delete_policy" ON public.neighbor_wishes 
  FOR DELETE USING (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND author_id = auth.uid()::text
    )
  );

-- ----------------------------------------------------------------------------
-- DISPUTES POLICIES (Complainant, Respondent or Admin access)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public read disputes" ON public.disputes;
DROP POLICY IF EXISTS "Public insert disputes" ON public.disputes;
DROP POLICY IF EXISTS "Public update disputes" ON public.disputes;
DROP POLICY IF EXISTS "disputes_select_policy" ON public.disputes;
DROP POLICY IF EXISTS "disputes_insert_policy" ON public.disputes;
DROP POLICY IF EXISTS "disputes_update_policy" ON public.disputes;

CREATE POLICY "disputes_select_policy" ON public.disputes 
  FOR SELECT USING (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND (
        complainant_id = auth.uid()::text 
        OR respondent_id = auth.uid()::text 
        OR auth.jwt() ->> 'email' LIKE '%@swapnorge.no'
      )
    )
  );

CREATE POLICY "disputes_insert_policy" ON public.disputes 
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND complainant_id = auth.uid()::text
    )
  );

CREATE POLICY "disputes_update_policy" ON public.disputes 
  FOR UPDATE USING (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND (
        complainant_id = auth.uid()::text 
        OR respondent_id = auth.uid()::text 
        OR auth.jwt() ->> 'email' LIKE '%@swapnorge.no'
      )
    )
  );

-- ----------------------------------------------------------------------------
-- REPORTS POLICIES (Reporter creates and tracks, Admin resolves)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public read reports" ON public.reports;
DROP POLICY IF EXISTS "Public insert reports" ON public.reports;
DROP POLICY IF EXISTS "Public update reports" ON public.reports;
DROP POLICY IF EXISTS "reports_select_policy" ON public.reports;
DROP POLICY IF EXISTS "reports_insert_policy" ON public.reports;
DROP POLICY IF EXISTS "reports_update_policy" ON public.reports;

CREATE POLICY "reports_select_policy" ON public.reports 
  FOR SELECT USING (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND (
        reporter_id = auth.uid()::text 
        OR auth.jwt() ->> 'email' LIKE '%@swapnorge.no'
      )
    )
  );

CREATE POLICY "reports_insert_policy" ON public.reports 
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND reporter_id = auth.uid()::text
    )
  );

CREATE POLICY "reports_update_policy" ON public.reports 
  FOR UPDATE USING (
    auth.role() = 'service_role' 
    OR (
      auth.role() = 'authenticated' AND auth.jwt() ->> 'email' LIKE '%@swapnorge.no'
    )
  );

-- ============================================================================
-- 7. SEED DATA (High-Fidelity Sample Initial Records)
-- ============================================================================
INSERT INTO public.partner_vouchers (id, partner_name, category, title, description, points_cost, real_value_nok, stock_total, stock_remaining, is_active, logo_emoji, image_url, valid_days, terms)
VALUES
  ('perk-kaffebrenneriet-coffee', 'Kaffebrenneriet', 'coffee', '1 Gratis Barista Kaffe eller Latte', 'Nyt en ferskbrent kaffe, cappuccino eller caffe latte hos Kaffebrenneriet i Oslo/Bergen.', 500, 55, 100, 86, true, '☕', 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&q=80&w=600', 30, 'Gjelder alle varme drikker i standard størrelse hos deltakende filialer.'),
  ('perk-godt-brod-bolle', 'Godt Brød', 'bakery', '1 Økologisk Kanel- eller Kardemommebolle', 'Ekte økologisk håndverksbakst fra Godt Brød. Perfekt belønning for gjenbruk i nabolaget.', 300, 38, 100, 72, true, '🥐', 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&q=80&w=600', 30, 'Kan hentes i alle Godt Brød bakerier mot fremvisning av digital kupongkode.'),
  ('perk-rema-kiwi-voucher', 'Nærbutikk / Kiwi & Rema', 'groceries', '25 kr Avslag på Frukt & Grønt', 'Støtt et sunt nabolag! Få 25 kr rabatt på fersk frukt og grønnsaker i nærbutikken.', 250, 25, 100, 64, true, '🛒', 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=600', 45, 'Gjelder ved kjøp over 50 kr i frukt- og grøntavdelingen.'),
  ('perk-bua-friluft', 'BUA / Utstyrsbank', 'sports', '50 kr Prioritert Utstyrsservice', 'Slipp køen og få preparert langrennsski eller lånt teltutstyr til helgeturen.', 450, 50, 100, 91, true, '🎿', 'https://images.unsplash.com/photo-1551698618-1dfe5d97d256?auto=format&fit=crop&q=80&w=600', 60, 'Gyldig hos deltakende BUA- og friluftsavdelinger.'),
  ('perk-haralds-vaffel', 'Haralds Vaffel', 'bakery', '1 Norsk Tradisjonsvaffel med Brunost', 'En ekte norsk klassiker med rømme og Gudbrandsdalsost på Grünerløkka.', 200, 28, 100, 78, true, '🧇', 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?auto=format&fit=crop&q=80&w=600', 30, 'Vis kupongkode i kassen ved bestilling.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.voucher_redemptions (id, voucher_id, code, user_id, partner_name, title, points_cost, real_value_nok, is_used, redeemed_at, expires_at)
VALUES
  ('red-001', 'perk-kaffebrenneriet-coffee', 'KAF-8321', 'usr-nora-01', 'Kaffebrenneriet', '1 Gratis Barista Kaffe eller Latte', 500, 55, false, timezone('utc'::text, now() - interval '3 hours'), timezone('utc'::text, now() + interval '28 days')),
  ('red-002', 'perk-godt-brod-bolle', 'GOD-4912', 'usr-lars-02', 'Godt Brød', '1 Økologisk Kanel- eller Kardemommebolle', 300, 38, true, timezone('utc'::text, now() - interval '18 hours'), timezone('utc'::text, now() + interval '25 days')),
  ('red-003', 'perk-rema-kiwi-voucher', 'REM-1094', 'usr-sofie-03', 'Nærbutikk / Kiwi & Rema', '25 kr Avslag på Frukt & Grønt', 250, 25, true, timezone('utc'::text, now() - interval '42 hours'), timezone('utc'::text, now() + interval '40 days')),
  ('red-004', 'perk-haralds-vaffel', 'HAR-6752', 'usr-jonas-04', 'Haralds Vaffel', '1 Norsk Tradisjonsvaffel med Brunost', 200, 28, false, timezone('utc'::text, now() - interval '5 hours'), timezone('utc'::text, now() + interval '27 days'))
ON CONFLICT (id) DO NOTHING;
