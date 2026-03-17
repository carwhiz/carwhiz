# CarWhizz - Smart Car Management & Authorization System

CarWhizz is a modern Progressive Web App (PWA) built with Svelte, TypeScript, and Supabase. It provides a secure authentication system with email, phone number, and 6-digit PIN-based login and signup functionality.

## Features

- 🔐 **Secure Authentication** - Email + Phone Number + 6-Digit PIN
- 📱 **Responsive Design** - Optimized for mobile and desktop
- 🚀 **PWA Support** - Installable and works offline
- 💾 **Supabase Integration** - Real-time database and auth
- 🎨 **Modern UI** - Beautiful gradient design with smooth animations
- 🔄 **Form Validation** - Real-time email, phone, and password validation
- ♿ **Accessibility** - WCAG 2.1 compliant

## Technology Stack

- **Frontend**: Svelte 5 + TypeScript
- **Build Tool**: Vite 8
- **Database**: Supabase
- **PWA**: Vite Plugin PWA
- **Deployment**: Vercel (Recommended)

## Project Structure

```
src/
├── components/
│   ├── Login.svelte          # Login component
│   └── SignUp.svelte         # Sign up component
├── lib/
│   ├── services/
│   │   └── authService.ts    # Authentication logic
│   ├── utils/
│   └── supabaseClient.ts     # Supabase configuration
├── stores/
│   └── authStore.ts          # Svelte store for auth state
├── types/
│   └── auth.ts               # TypeScript type definitions
├── App.svelte                # Main app component
├── main.ts                   # Entry point
└── app.css                   # Global styles
public/
├── logo.svg                  # CarWhizz logo
└── manifest.json             # PWA manifest (auto-generated)
```

## Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn
- Supabase account

### Installation

1. **Clone the repository** (or use the existing folder):
   ```bash
   cd CARWHIZZ
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Set up environment variables**:
   Create a `.env` file in the root directory:
   ```env
   VITE_SUPABASE_URL=https://your-project.supabase.co
   VITE_SUPABASE_ANON_KEY=your-anon-key
   VITE_APP_NAME=CarWhizz
   VITE_APP_VERSION=1.0.0
   ```

   Replace `your-project` and `your-anon-key` with your actual Supabase credentials.

4. **Start the development server**:
   ```bash
   npm run dev
   ```

   Open [http://localhost:5173](http://localhost:5173) in your browser.

## Supabase Setup

### 1. Create a Users Table

```sql
create table users (
  id uuid primary key,
  email text unique not null,
  phone_number text not null,
  created_at timestamp default now()
);

alter table users enable row level security;

create policy "Users can view their own data" on users
  for select using (auth.uid() = id);

create policy "Users can update their own data" on users
  for update using (auth.uid() = id);
```

### 2. Configure Auth Settings

1. Go to Supabase Dashboard → Authentication → Policies
2. Set password policy (minimum 6 characters recommended for PIN)
3. Enable Email provider (default)
4. Configure email templates in Authentication → Email Templates

## Development

### Available Scripts

```bash
# Start development server with hot reload
npm run dev

# Build for production
npm run build

# Preview production build locally
npm run preview

# Type check TypeScript
npm run check
```

### Login Page Features

- Email validation with real-time feedback
- 6-digit PIN code input (numeric only)
- Form state management
- Error handling and display
- Loading states
- Keyboard shortcuts (Enter to submit)

### Sign Up Page Features

- Email validation
- Phone number formatting and validation
- 6-digit PIN confirmation
- Terms of Service acceptance
- Comprehensive error messages
- Account creation with Supabase Auth

## Responsive Design

### Mobile (< 480px)
- Full-screen forms
- Touch-optimized inputs
- Larger tap targets
- Reduced padding for compact displays

### Tablet (480px - 768px)
- Optimized card width
- Balanced spacing
- Touch-friendly controls

### Desktop (> 768px)
- Centered card layout
- Maximum width constraint
- Enhanced visual hierarchy

## Password Validation

- **Format**: Exactly 6 digits (0-9)
- **Input Type**: Numeric only with masked display
- **Client-side**: Instant validation feedback
- **Server-side**: Additional validation in authentication service

## PWA Installation

The app can be installed as a PWA on:
- Desktop (Chrome, Edge, Firefox, Safari 16+)
- Android (All modern browsers)
- iOS (Safari 16.4+)

### Installation Steps

**Desktop:**
1. Click the install icon in the address bar
2. Follow the browser's installation prompt

**Mobile:**
1. Open the app in a mobile browser
2. Use the "Add to Home Screen" option from the browser menu

## Build & Deployment

### Building for Production

```bash
npm run build
```

This creates an optimized, minified production build in the `dist/` folder.

### Deploying on Vercel

1. **Connect your repository** to Vercel
2. **Set environment variables** in Vercel project settings:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
3. **Deploy**:
   ```bash
   vercel deploy
   ```

### Manual Deployment

1. Build the project:
   ```bash
   npm run build
   ```

2. Deploy the `dist` folder to your hosting provider (Netlify, GitHub Pages, AWS S3, etc.)

## Troubleshooting

### Service Worker Issues
- Clear browser cache and site data
- Hard refresh (Ctrl+Shift+R or Cmd+Shift+R)
- Check Network tab in DevTools

### Supabase Connection Issues
- Verify environment variables are correctly set
- Check CORS settings in Supabase project
- Ensure API keys are active

### Phone Number Validation
- Supports international formats
- Remove spaces and special characters for validation
- Examples: `+1-234-567-8900`, `1234567890`, `(123) 456-7890`

## Security Considerations

- Never commit `.env` files with real credentials
- All auth operations happen server-side with Supabase Auth
- PINs are encrypted by Supabase
- Use HTTPS in production
- Keep dependencies updated regularly

## Performance Optimization

- **Code Splitting**: Automatic with Vite
- **Lazy Loading**: Components are pre-loaded for auth pages
- **Service Worker**: Caches assets for offline functionality
- **Minification**: Production build includes minified CSS and JS
- **Tree Shaking**: Unused code is automatically removed

## Browser Support

- Chrome/Edge 90+
- Firefox 88+
- Safari 15+ (14+ with limitations)
- Mobile browsers (iOS Safari 14+, Chrome Android)

## Contributing

Contributions are welcome! Follow these steps:

1. Create a feature branch (`git checkout -b feature/amazing-feature`)
2. Commit changes (`git commit -m 'Add amazing feature'`)
3. Push to branch (`git push origin feature/amazing-feature`)
4. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check existing GitHub issues
2. Create a new issue with detailed description
3. Include browser and OS information
4. Attach error screenshots if applicable

## Roadmap

- [ ] Two-factor authentication
- [ ] Social login (Google, GitHub)
- [ ] User profile management
- [ ] Dashboard with car data
- [ ] Multi-language support
- [ ] Dark mode toggle
- [ ] OTP via SMS/Email

## Acknowledgments

- Svelte team for the amazing framework
- Supabase for backend services
- Vite for the fast build tool
- Contributors and users

---

**Made with ❤️ by CarWhizz Team**
