import React from 'react';
import { Link } from 'react-router-dom';

const Sidebar = () => {
    return (
        <aside className="w-64 bg-gray-800 text-white h-screen p-4">
            <nav>
                <ul className="space-y-2">
                    <li><Link to="/dashboard" className="block p-2 hover:bg-gray-700 rounded">Dashboard</Link></li>
                    <li><Link to="/calendar" className="block p-2 hover:bg-gray-700 rounded">Calendar</Link></li>
                    <li><Link to="/clients" className="block p-2 hover:bg-gray-700 rounded">Clients</Link></li>
                    <li><Link to="/services" className="block p-2 hover:bg-gray-700 rounded">Services</Link></li>
                </ul>
            </nav>
        </aside>
    );
};

export default Sidebar;
