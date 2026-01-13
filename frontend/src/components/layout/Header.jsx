import React from 'react';

const Header = () => {
    return (
        <header className="bg-white shadow p-4 flex justify-between items-center">
            <h1 className="text-xl font-bold">Yiyi Spa</h1>
            <div>
                {/* User profile or logout placeholder */}
                <span className="text-gray-600">Admin</span>
            </div>
        </header>
    );
};

export default Header;
