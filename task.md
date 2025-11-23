Based on current best practices and Firebase authentication patterns, here's a comprehensive prompt for an AI agent:

***

# AI Agent Prompt: Modern Authentication Screens with Firebase

## Objective
Create a modern, professional authentication flow consisting of:
1. **Splash Screen** - Animated brand introduction
2. **Login Screen** - Clean, accessible sign-in interface
3. **Signup Screen** - Frictionless registration form
4. **Firebase Authentication Integration** - Secure authentication implementation

***

## Technical Requirements

### Technology Stack
- **Framework**: React (with React Router for navigation)
- **Authentication**: Firebase Authentication (v9+ modular SDK)
- **Styling**: Modern CSS with CSS variables or Tailwind CSS
- **State Management**: React hooks (useState, useEffect)
- **Validation**: Client-side form validation with real-time feedback

### Firebase Setup
```javascript
// Initialize Firebase with this structure
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_AUTH_DOMAIN",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_STORAGE_BUCKET",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
```

***

## Screen Specifications

### 1. Splash Screen

**Design Requirements:**
- **Duration**: 2-3 seconds auto-transition
- **Animation**: Smooth fade-in of logo/brand name with subtle scale effect
- **Background**: Gradient or solid brand color
- **Elements**: 
  - Centered logo/app icon
  - App name/tagline (optional)
  - Loading indicator (subtle, minimal)
- **Transition**: Smooth fade to login/signup screen
- **Accessibility**: Respect `prefers-reduced-motion` for users with motion sensitivity

**Implementation Pattern:**
```javascript
// Auto-redirect after animation completes
useEffect(() => {
  const timer = setTimeout(() => {
    navigate('/login');
  }, 2500);
  return () => clearTimeout(timer);
}, []);
```

***

### 2. Login Screen

**Design Principles (2025 Best Practices):**
- **Minimalist layout** with generous white space
- **Mobile-first responsive design** (works seamlessly on all devices)
- **Large touch targets** (min 44x44px for buttons)
- **Clear visual hierarchy** with proper contrast ratios (WCAG 2.1 AA compliant)

**Required Elements:**

1. **Header Section**
   - "Welcome Back" or "Sign In" title
   - Optional subtitle or brand tagline

2. **Email Input Field**
   - Label: "Email Address"
   - Input type: `email`
   - Attributes: `autocomplete="email"`, `required`
   - Real-time validation with inline feedback
   - Error states: "Please enter a valid email"

3. **Password Input Field**
   - Label: "Password"
   - Input type: `password`
   - Show/hide password toggle icon
   - Attributes: `autocomplete="current-password"`, `required`
   - Error states: Clear error messages

4. **Remember Me Checkbox** (optional but recommended)
   - Persists session using Firebase persistence

5. **Primary CTA Button**
   - Text: "Sign In" or "Log In"
   - Full-width on mobile, fixed width on desktop
   - Loading state with spinner when processing
   - Disabled state while form is invalid

6. **Forgot Password Link**
   - Positioned below password field
   - Triggers password reset email via `sendPasswordResetEmail()`

7. **Social Sign-In Options** (recommended)
   - "Continue with Google" button
   - Optional: Apple, Facebook, GitHub
   - Visually distinct from primary button

8. **Sign-Up Redirect**
   - Text: "Don't have an account? **Sign Up**"
   - Clear link to signup screen

**Validation Rules:**
- Email format validation (regex)
- Minimum password requirements check
- Show errors **after** user finishes typing (on blur or submit)
- Success indicators (green checkmarks when valid)

**Firebase Implementation:**
```javascript
import { signInWithEmailAndPassword, signInWithPopup, GoogleAuthProvider } from 'firebase/auth';

// Email/Password Login
const handleLogin = async (email, password) => {
  try {
    const userCredential = await signInWithEmailAndPassword(auth, email, password);
    // Navigate to dashboard/home
  } catch (error) {
    // Show user-friendly error: "Invalid email or password"
    setError(error.code);
  }
};

// Google Sign-In
const handleGoogleSignIn = async () => {
  const provider = new GoogleAuthProvider();
  try {
    await signInWithPopup(auth, provider);
  } catch (error) {
    setError(error.message);
  }
};
```

***

### 3. Signup Screen

**Design Principles:**
- **Reduce friction**: Ask for minimum information upfront
- **Progressive disclosure**: Only essential fields visible initially
- **Encouraging copy**: Use friendly, welcoming language

**Required Elements:**

1. **Header Section**
   - "Create Account" or "Get Started" title
   - Subtext: "Join thousands of users" (social proof)

2. **Full Name Input** (optional, can be added later)
   - Label: "Full Name"
   - Input type: `text`
   - Attributes: `autocomplete="name"`

3. **Email Input Field**
   - Label: "Email Address"
   - Input type: `email`
   - Attributes: `autocomplete="email"`, `required`
   - Real-time validation with availability check (optional)
   - Success state: Green checkmark when valid

4. **Password Input Field**
   - Label: "Password"
   - Input type: `password`
   - Show/hide toggle
   - Attributes: `autocomplete="new-password"`, `required`
   - **Password strength indicator** (visual bar: weak/medium/strong)
   - **Visible requirements checklist**:
     - ✓ At least 8 characters
     - ✓ One uppercase letter
     - ✓ One number
     - ✓ One special character

5. **Confirm Password** (optional - modern UX suggests skipping this)
   - If included, show inline validation
   - Better alternative: Use strong password requirements + reset option

6. **Terms & Privacy Checkbox**
   - "I agree to the [Terms of Service] and [Privacy Policy]"
   - Required before signup
   - Links open in new tab

7. **Primary CTA Button**
   - Text: "Create Account" or "Sign Up"
   - Full-width on mobile
   - Loading state with spinner
   - Disabled until all validations pass

8. **Social Sign-Up Options**
   - "Sign up with Google"
   - Consistent with login screen

9. **Login Redirect**
   - Text: "Already have an account? **Log In**"

**Firebase Implementation:**
```javascript
import { createUserWithEmailAndPassword, updateProfile } from 'firebase/auth';

const handleSignup = async (email, password, displayName) => {
  try {
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    
    // Update user profile with name
    await updateProfile(userCredential.user, {
      displayName: displayName
    });
    
    // Optional: Send email verification
    await sendEmailVerification(userCredential.user);
    
    // Navigate to onboarding or dashboard
  } catch (error) {
    // Handle errors: "Email already in use", etc.
    setError(getReadableError(error.code));
  }
};
```

***

## Authentication Flow Logic

### Protected Routes
```javascript
import { onAuthStateChanged } from 'firebase/auth';

// Create auth context or hook
useEffect(() => {
  const unsubscribe = onAuthStateChanged(auth, (user) => {
    if (user) {
      setCurrentUser(user);
      // User is logged in
    } else {
      setCurrentUser(null);
      // Redirect to login
    }
  });
  return unsubscribe;
}, []);
```

### Password Reset Flow
```javascript
import { sendPasswordResetEmail } from 'firebase/auth';

const handlePasswordReset = async (email) => {
  try {
    await sendPasswordResetEmail(auth, email);
    // Show success: "Check your inbox for reset link"
  } catch (error) {
    setError("Unable to send reset email");
  }
};
```

### Sign Out
```javascript
import { signOut } from 'firebase/auth';

const handleSignOut = async () => {
  await signOut(auth);
  navigate('/login');
};
```

***

## Design System (Color Scheme)

**Use modern, accessible colors:**

```css
:root {
  /* Primary Brand Colors */
  --primary: #3B82F6; /* Blue */
  --primary-hover: #2563EB;
  --primary-light: #DBEAFE;
  
  /* Neutrals */
  --background: #FFFFFF;
  --surface: #F9FAFB;
  --text-primary: #111827;
  --text-secondary: #6B7280;
  --border: #E5E7EB;
  
  /* Status Colors */
  --success: #10B981;
  --error: #EF4444;
  --warning: #F59E0B;
  
  /* Dark Mode (optional) */
  @media (prefers-color-scheme: dark) {
    --background: #0F172A;
    --surface: #1E293B;
    --text-primary: #F1F5F9;
    --text-secondary: #94A3B8;
    --border: #334155;
  }
}
```

***

## Accessibility Requirements (WCAG 2.1 AA)

1. **Keyboard Navigation**
   - Tab through all interactive elements in logical order
   - Enter key submits forms
   - Visible focus indicators on all inputs/buttons

2. **Screen Reader Support**
   - Proper ARIA labels on inputs
   - Error messages announced via `aria-live="polite"`
   - Form validation feedback is accessible

3. **Color Contrast**
   - Text contrast ratio minimum 4.5:1
   - Interactive elements minimum 3:1

4. **Form Labels**
   - All inputs have associated `<label>` elements
   - Placeholder text is NOT the only label

5. **Error Handling**
   - Errors are specific: "Password must be at least 8 characters" not "Invalid input"
   - Error location is clear (red border + icon + message)
   - Error messages visible to screen readers

***

## Mobile Optimization

- **Responsive breakpoints**: 320px, 768px, 1024px
- **Touch targets**: Minimum 44x44px for all buttons/links
- **Keyboard types**: Use appropriate `inputmode` attributes
  - Email: `inputmode="email"`
  - Password: `inputmode="text"`
- **No horizontal scrolling**
- **Autofocus on first input** (desktop only)
- **Auto-capitalize off** for email fields

***

## Error Handling & User Feedback

**Firebase Error Code Translations:**
```javascript
const getReadableError = (errorCode) => {
  const errors = {
    'auth/email-already-in-use': 'This email is already registered',
    'auth/invalid-email': 'Please enter a valid email address',
    'auth/weak-password': 'Password should be at least 6 characters',
    'auth/user-not-found': 'No account found with this email',
    'auth/wrong-password': 'Incorrect password',
    'auth/too-many-requests': 'Too many attempts. Please try again later',
    'auth/network-request-failed': 'Network error. Check your connection'
  };
  return errors[errorCode] || 'An error occurred. Please try again';
};
```

***

## Performance Optimization

- **Code splitting**: Lazy load authentication screens
- **Image optimization**: Use WebP format for logos, max 200KB
- **Firebase tree-shaking**: Only import needed auth methods
- **Form validation debouncing**: 300ms delay on real-time checks
- **Loading states**: Show spinners during async operations

***

## Security Best Practices

1. **Never store passwords** in state or localStorage
2. **Use HTTPS** in production
3. **Implement rate limiting** for repeated login attempts
4. **Email verification** for new accounts (optional but recommended)
5. **Password requirements**: Minimum 8 characters, mixed case, numbers, symbols
6. **Session management**: Use Firebase's built-in token refresh

***

## Deliverables

Create the following files:

1. **SplashScreen.jsx** - Animated splash with auto-navigation
2. **LoginScreen.jsx** - Complete login form with Firebase integration
3. **SignupScreen.jsx** - Registration form with validation
4. **firebase.js** - Firebase configuration and initialization
5. **App.jsx** - Router setup with protected routes
6. **styles.css** or **Tailwind config** - Design system implementation

***

## Testing Checklist

- [ ] Forms submit on Enter key
- [ ] Tab navigation works logically
- [ ] All error states display correctly
- [ ] Password show/hide toggles work
- [ ] Social login redirects properly
- [ ] Email verification sends successfully
- [ ] Password reset works end-to-end
- [ ] Responsive on mobile (320px+)
- [ ] Works in Chrome, Safari, Firefox, Edge
- [ ] Screen reader announces errors
- [ ] Loading states prevent double submissions
- [ ] User redirects to dashboard after successful login

***

**Note**: Replace placeholder Firebase config values with your actual project credentials from the Firebase Console. Enable Email/Password authentication in Firebase Console > Authentication > Sign-in Methods.

This implementation follows 2025 best practices for UX, accessibility, security, and performance while providing a smooth, modern authentication experience.

Sources
[1] 10 Best AI App Splash Screen Maker Tools in 2025 https://www.pixazo.ai/blog/best-ai-app-splash-screen-maker-tools
[2] Login & Signup UX: The 2025 Guide to Best Practices ... https://www.authgear.com/post/login-signup-ux-guide
[3] Get Started with Firebase Authentication on Websites https://firebase.google.com/docs/auth/web/start
[4] Splash Screen https://dribbble.com/tags/splash-screen
[5] 10 Examples of Login Page Design & Best Practices https://arounda.agency/blog/10-examples-of-login-page-design-best-practices
[6] Firebase Authentication in React: A Simple Step-by- ... https://dev.to/fonyuygita/firebase-authentication-in-react-a-simple-step-by-step-guide-24m6
[7] Free App Splash Screen Templates & Examples https://www.figma.com/community/mobile-apps/splash-screens
[8] Sign-in form best practices https://web.dev/articles/sign-in-form-best-practices
[9] Get Started with Firebase Authentication on Android https://firebase.google.com/docs/auth/android/start
[10] 50 inspiring splash screen designs https://www.justinmind.com/blog/splash-screen-designs/
