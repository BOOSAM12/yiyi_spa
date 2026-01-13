import React from 'react';

const Dashboard = () => {
    return (
        <div className="p-6">
            <h2 className="text-2xl font-bold mb-4">Dashboard</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="bg-white p-4 rounded shadow">
                    <h3 className="text-lg font-semibold">Total Clients</h3>
                    <p className="text-3xl font-bold">120</p>
                </div>
                <div className="bg-white p-4 rounded shadow">
                    <h3 className="text-lg font-semibold">Appointments Today</h3>
                    <p className="text-3xl font-bold">5</p>
                </div>
                <div className="bg-white p-4 rounded shadow">
                    <h3 className="text-lg font-semibold">Revenue</h3>
                    <p className="text-3xl font-bold">$1,200</p>
                </div>
            </div>
        </div>
    );
};

export default Dashboard;
