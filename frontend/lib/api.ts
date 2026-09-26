export const API=process.env.NEXT_PUBLIC_API_URL||'http://127.0.0.1:5000';
export async function getJSON(path:string){const r=await fetch(`${API}${path}`,{cache:'no-store'});const j=await r.json();if(!r.ok)throw new Error(j.error||'Request failed');return j}
