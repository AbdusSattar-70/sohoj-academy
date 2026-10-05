'use client';
import {createBrowserClient} from '@supabase/ssr';
import type {AcademyDatabase} from '@/types/academy-rpc';
export function createClient(){return createBrowserClient<AcademyDatabase>(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!);}
