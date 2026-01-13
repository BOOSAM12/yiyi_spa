import { BrowserRouter, Routes, Route } from "react-router-dom"
import Login from "../pages/Login"
import Dashboard from "../pages/Dashboard"
import Calendar from "../pages/Calendar"
import Clients from "../pages/Clients"
import Services from "../pages/Services"
import NotFound from "../pages/NotFound"

export default function AppRoutes() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Login />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/agenda" element={<Calendar />} />
        <Route path="/clientes" element={<Clients />} />
        <Route path="/servicios" element={<Services />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  )
}
