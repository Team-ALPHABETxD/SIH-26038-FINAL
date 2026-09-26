'use client';
import Link from 'next/link';
import {usePathname} from 'next/navigation';
import {useState} from 'react';
import {Activity,ArrowUpRight,Eye,Menu,X} from 'lucide-react';

export function AppShell({children}){
 const path=usePathname(); const [open,setOpen]=useState(false);
 const nav=[['/','Home'],['/dashboard','Dashboard'],['/screening','Screening'],['/history','History'],['/how-it-works','How it works'],['/about','About']];
 return <div className="app-shell">
  <header className="topbar"><div className="topinner">
   <Link className="brand" href="/"><span className="brandmark"><Eye/></span><span><strong>eyeQ</strong><em> AI</em><small>RETINAL DECISION SUPPORT</small></span></Link>
   <nav className={open?'nav open':'nav'}>{nav.map(([href,label])=><Link key={href} className={path===href?'active':''} href={href} onClick={()=>setOpen(false)}>{label}</Link>)}</nav>
   <div className="top-actions"><span className="system-chip"><i/> MATLAB bridge ready</span><Link href="/screening" className="newbtn">New screening <ArrowUpRight size={15}/></Link><button className="menubtn" aria-label="Open navigation" onClick={()=>setOpen(!open)}>{open?<X/>:<Menu/>}</button></div>
  </div></header>
  <main>{children}</main>
  <footer><div><b>eyeQ AI</b><span>AI-assisted diabetic retinopathy screening</span></div><span>Developed by Team Alphabet.</span><span>For clinical decision support, not standalone diagnosis.</span></footer>
 </div>
}
