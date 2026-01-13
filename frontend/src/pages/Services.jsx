import React from 'react';

const Services = () => {
    return (
        <div className="p-6">
            <h2 className="text-2xl font-bold mb-4">Services</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <div className="bg-white rounded-lg shadow p-6">
                    <h3 className="text-xl font-bold mb-2">Massage Therapy</h3>
                    <p className="text-gray-700 mb-4">Relaxing full body massage.</p>
                    <span className="text-blue-500 font-bold">$60</span>
                </div>
                <div className="bg-white rounded-lg shadow p-6">
                    <h3 className="text-xl font-bold mb-2">Facial</h3>
                    <p className="text-gray-700 mb-4">Rejuvenating facial treatment.</p>
                    <span className="text-blue-500 font-bold">$45</span>
                </div>
            </div>
        </div>
    );
};

export default Services;
