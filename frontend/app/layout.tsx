import './globals.css';
import {AppShell} from '../components/AppShell';
export const metadata={title:'eyeQ AI — Retinal Decision Support',description:'AI-assisted diabetic retinopathy screening with explainable evidence.'};
export default function RootLayout({children}){return <html lang="en"><body><AppShell>{children}</AppShell></body></html>}
