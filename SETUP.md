# CarWhizz Setup Guide

## Quick Start

### 1. Environment Setup

Copy `.env.example` to `.env` and fill in your Supabase credentials:

```bash
cp .env.example .env
```

Edit `.env`:
```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

### 2. Database Setup

In Supabase SQL Editor, run:

```sql
-- Create users table
create table public.users (
  id uuid primary key default auth.uid(),
  email text unique not null,
  phone_number text not null,
  created_at timestamp with time zone default now()
);

-- Enable RLS
alter table public.users enable row level security;

-- Create policies
create policy "Users can view their own data"
  on public.users for select
  using (auth.uid() = id);

create policy "Users can update their own data"
  on public.users for update
  using (auth.uid() = id);

create policy "Users can insert their own data"
  on public.users for insert
  with check (auth.uid() = id);
```

### 3. Install Dependencies

```bash
npm install
```

### 4. Start Development

```bash
npm run dev
```

Visit `http://localhost:5173`

## Authentication Fields

### Password Requirements
- **Format**: Exactly 6 digits (0-9)
- **Purpose**: Easy PIN-based authentication
- **Client Validation**: Numeric input only
- **Stored**: Via Supabase Auth (encrypted)

### Phone Number Format Support
- International: `+1-234-567-8900`
- US: `(123) 456-7890`
- Simple: `1234567890`
- Any format with 10+ digits

### Email Validation
- Standard email format check
- Case insensitive
- Unique per Supabase Auth

## Deployment

### Vercel Deployment

1. Push to GitHub
2. Connect repo to Vercel
3. Add environment variables:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
4. Deploy!

```bash
# Or deploy from CLI
vercel deploy
```

### Custom Deployment

```bash
# Build
npm run build

# Deploy dist/ folder to your host
netlify deploy --prod --dir=dist
# or
aws s3 sync dist s3://your-bucket
```

## Troubleshooting

### Build Issues
```bash
# Clear cache
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Service Worker Won't Register
- Check DevTools > Application > Service Workers
- Ensure HTTPS (or localhost)
- Check for errors in Console

### Supabase Connection Error
- Verify `.env` is loaded (`npm run dev` should show config)
- Check network requests in DevTools
- Verify API keys are active in Supabase

### Phone Number Not Validating
- Remove all special characters for validation
- Minimum 10 digits required
- Add `+` for international format

## Project Structure

```
src/
├── App.svelte              # Main app with routing
├── main.ts                 # Entry point
├── app.css                 # Global styles
├── components/
│   ├── Login.svelte        # Login page
│   └── SignUp.svelte       # Sign up page
├── lib/
│   ├── supabaseClient.ts   # Supabase init
│   └── services/
│       └── authService.ts  # Auth logic
├── stores/
│   └── authStore.ts        # State management
└── types/
    └── auth.ts             # TypeScript types

public/
├── logo.svg                # CarWhizz branding
└── favicon.ico

dist/                        # Production build (generated)
├── index.html
├── assets/
├── sw.js                   # Service worker
└── workbox-*.js            # PWA cache
```

## Key Files

### `src/lib/services/authService.ts`
Core authentication logic:
- `signUp()` - Create new user
- `login()` - Authenticate user
- `logout()` - Sign out
- Validation functions for all fields

### `src/stores/authStore.ts`
Global authentication state using Svelte stores

### `src/components/Login.svelte`
Login interface with:
- Email + Password (6-digit PIN)
- Real-time validation
- Error handling
- Responsive design

### `src/components/SignUp.svelte`
Sign up interface with:
- Email, Phone, Password confirmation
- Terms acceptance
- Phone number formatting
- Progressive validation

## Scripts Reference

```bash
npm run dev       # Dev server with HMR
npm run build     # Production build
npm run preview   # Preview built version
npm run check     # TypeScript & Svelte check
```

## Browser DevTools Tips

1. **Check Service Worker**: Application > Service Workers
2. **View Cache**: Application > Cache Storage
3. **Debug Auth**: Application > Local Storage (check Supabase tokens)
4. **Network**: Check API calls to Supabase
5. **Change Mobile View**: DevTools > Toggle device toolbar

## Performance Tips

- Service Worker caches static assets (CSS, JS, fonts)
- Images are optimized by Vite
- Code splitting ensures fast initial load
- PWA install adds to home screen

## Security Checklist

- [ ] Environment variables never hardcoded
- [ ] HTTPS enabled in production
- [ ] Supabase Row Level Security (RLS) enabled
- [ ] API keys rotated regularly
- [ ] CORS configured in Supabase
- [ ] Service worker over HTTPS only
