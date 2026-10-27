import { useParams } from 'react-router'

// Placeholder until step 2 builds the public portal from the mockup.
export function PortalArea() {
  const { slug = '' } = useParams()

  return <h1>Reserva en {slug}</h1>
}
