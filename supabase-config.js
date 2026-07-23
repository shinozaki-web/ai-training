const SUPABASE_URL = 'https://lnszvaeomaeukazkfilm.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxuc3p2YWVvbWFldWthemtmaWxtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3Njg3OTMsImV4cCI6MjEwMDM0NDc5M30.shEWblBNcUCllX8kByrnaHAxsy4HHhEeSb58aFMzilY';

const { createClient } = supabase;
const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
