import React from 'react';
import { Link } from 'react-router-dom';

const NotFound = () => {
    return (
        <div className="flex h-screen flex-col items-center justify-center bg-gray-100">
            <h1 className="text-6xl font-bold text-gray-800">404</h1>
            <p className="text-xl text-gray-600 mb-4">Page Not Found</p>
            <Link to="/" className="text-blue-500 hover:underline">Go Home</Link>
        </div>
    );
};

export default NotFound;
