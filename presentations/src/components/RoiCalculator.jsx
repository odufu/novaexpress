import React, { useState } from 'react';
import { 
  Calculator, 
  TrendingUp, 
  Server, 
  CreditCard, 
  Bike, 
  DollarSign,
  Percent,
  Warehouse
} from 'lucide-react';

export default function RoiCalculator() {
  const [dailyOrders, setDailyOrders] = useState(3500);
  const [dcs, setDcs] = useState(6);
  const [riders, setRiders] = useState(85);
  const [aov, setAov] = useState(22500);
  const [directTransferPct, setDirectTransferPct] = useState(45);

  const fmtNaira = (val) => '₦' + Math.round(val).toLocaleString('en-NG');
  const fmtUsd = (val) => '$' + Math.round(val).toLocaleString('en-US');

  // Computations (30-day basis)
  const monthlyOrders = dailyOrders * 30;
  const monthlyGmv = monthlyOrders * aov;

  // Platform delivery & handling revenue (avg ₦2,500/order charged to merchant + ₦400 warehousing/pack fee)
  const grossPlatformRevenue = monthlyOrders * 2900;

  // Rider payouts: Commission (₦1,000) + Transport/Fuel (₦750 avg) = ₦1,750
  const riderPayouts = monthlyOrders * 1750;

  // Supabase & Cloud Infrastructure
  let supabaseComputeUsd = 25; // Pro Base
  if (dailyOrders <= 500) supabaseComputeUsd += 10;
  else if (dailyOrders <= 3000) supabaseComputeUsd += 60;
  else if (dailyOrders <= 15000) supabaseComputeUsd += 160;
  else supabaseComputeUsd += 350;

  const storageAndEgressUsd = Math.min(250, 15 + Math.round(monthlyOrders * 0.002));
  const totalInfraUsd = supabaseComputeUsd + storageAndEgressUsd;
  const serverCostNaira = totalInfraUsd * 1550;

  // Payment gateway fees: Monnify 0.75% cap ₦200 + Paystack 1.5% cap ₦2,000
  const directTransferOrders = monthlyOrders * (directTransferPct / 100);
  const cardOrders = monthlyOrders * 0.15;
  const monnifyFees = directTransferOrders * Math.min(200, aov * 0.0075);
  const paystackFees = cardOrders * Math.min(2000, aov * 0.015);
  const totalGatewayFees = monnifyFees + paystackFees;

  // SMS & WhatsApp Alerts (~₦3.50 per notification, 2 per delivery)
  const smsCharges = monthlyOrders * 2 * 3.5;

  // Total OpEx and Margin
  const totalOpEx = riderPayouts + serverCostNaira + totalGatewayFees + smsCharges;
  const netProfit = grossPlatformRevenue - totalOpEx;
  const marginPct = ((netProfit / grossPlatformRevenue) * 100).toFixed(1);

  return (
    <div className="animate-fade-in" style={{ padding: '1rem 0' }}>
      {/* Section Header */}
      <div style={{ marginBottom: '2.5rem' }}>
        <span style={{
          color: 'var(--brand-primary)',
          fontFamily: 'var(--font-mono)',
          fontSize: '0.8rem',
          fontWeight: 700,
          textTransform: 'uppercase',
          letterSpacing: '0.1em',
          display: 'block',
          marginBottom: '0.5rem',
        }}>
          Interactive Financial Engine
        </span>
        <h2 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '2.4rem',
          fontWeight: 800,
          color: 'var(--text-primary)',
          letterSpacing: '-0.02em',
          marginBottom: '0.75rem',
        }}>
          Live ROI, Server Charges & Profit Margin Calculator
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '1.05rem', maxWidth: '800px' }}>
          Simulate operational scaling: Adjust daily order volume, active hubs, fleet size, and payment splits to see instant cloud server costs, payment gateway fees, and net operating margin in Nigerian Naira.
        </p>
      </div>

      {/* Main Grid */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))',
        gap: '2.5rem',
      }}>
        {/* Left: Reactive Controls */}
        <div style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-xl)',
          padding: '2.25rem',
          boxShadow: 'var(--shadow-md)',
        }}>
          <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.3rem', fontWeight: 800, marginBottom: '1.75rem', color: 'var(--text-primary)' }}>
            Operational Input Parameters
          </h3>

          {/* Slider 1: Daily Orders */}
          <div style={{ marginBottom: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
              <span style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--text-primary)' }}>Daily Completed Deliveries</span>
              <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--brand-primary)' }}>
                {dailyOrders.toLocaleString()} orders / day
              </span>
            </div>
            <input
              type="range"
              min="200"
              max="25000"
              step="100"
              value={dailyOrders}
              onChange={(e) => setDailyOrders(Number(e.target.value))}
              style={{ width: '100%', accentColor: 'var(--brand-primary)', cursor: 'pointer' }}
            />
          </div>

          {/* Slider 2: Distribution Centers */}
          <div style={{ marginBottom: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
              <span style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--text-primary)' }}>Regional Distribution Centers (DCs)</span>
              <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--brand-orange)' }}>
                {dcs} Hubs
              </span>
            </div>
            <input
              type="range"
              min="1"
              max="25"
              step="1"
              value={dcs}
              onChange={(e) => setDcs(Number(e.target.value))}
              style={{ width: '100%', accentColor: 'var(--brand-orange)', cursor: 'pointer' }}
            />
          </div>

          {/* Slider 3: Active Fleet */}
          <div style={{ marginBottom: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
              <span style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--text-primary)' }}>Active Fleet Riders</span>
              <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--brand-primary)' }}>
                {riders} Active Riders
              </span>
            </div>
            <input
              type="range"
              min="10"
              max="500"
              step="5"
              value={riders}
              onChange={(e) => setRiders(Number(e.target.value))}
              style={{ width: '100%', accentColor: 'var(--brand-primary)', cursor: 'pointer' }}
            />
          </div>

          {/* Slider 4: AOV */}
          <div style={{ marginBottom: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
              <span style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--text-primary)' }}>Average Order Value (AOV)</span>
              <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--brand-primary)' }}>
                {fmtNaira(aov)}
              </span>
            </div>
            <input
              type="range"
              min="5000"
              max="60000"
              step="500"
              value={aov}
              onChange={(e) => setAov(Number(e.target.value))}
              style={{ width: '100%', accentColor: 'var(--brand-primary)', cursor: 'pointer' }}
            />
          </div>

          {/* Slider 5: Monnify Direct Transfer Share */}
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
              <span style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--text-primary)' }}>Monnify Direct Transfer Share</span>
              <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--brand-primary)' }}>
                {directTransferPct}% (Zero Cash Liability)
              </span>
            </div>
            <input
              type="range"
              min="10"
              max="85"
              step="5"
              value={directTransferPct}
              onChange={(e) => setDirectTransferPct(Number(e.target.value))}
              style={{ width: '100%', accentColor: 'var(--brand-primary)', cursor: 'pointer' }}
            />
          </div>
        </div>

        {/* Right: Calculated Outputs */}
        <div style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-xl)',
          padding: '2.25rem',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          boxShadow: 'var(--shadow-lg)',
        }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1.75rem' }}>
              <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>
                Monthly Financial Projection
              </h3>
              <span style={{
                background: 'var(--brand-primary-subtle)',
                border: '1px solid rgba(0, 108, 76, 0.3)',
                color: 'var(--brand-primary)',
                fontFamily: 'var(--font-mono)',
                fontSize: '0.85rem',
                fontWeight: 800,
                padding: '4px 12px',
                borderRadius: '8px',
              }}>
                {marginPct}% Margin
              </span>
            </div>

            {/* Metric Rows */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '0.75rem', borderBottom: '1px solid var(--border-subtle)' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Monthly Gross Merchandise Value (GMV)</span>
                <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--text-primary)' }}>{fmtNaira(monthlyGmv)}</span>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '0.75rem', borderBottom: '1px solid var(--border-subtle)' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Gross Logistics Revenue (Delivery + Warehousing)</span>
                <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--brand-primary)' }}>{fmtNaira(grossPlatformRevenue)}</span>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '0.75rem', borderBottom: '1px solid var(--border-subtle)' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Rider Compensation (Commission + Fuel)</span>
                <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--accent-rose)' }}>-{fmtNaira(riderPayouts)}</span>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '0.75rem', borderBottom: '1px solid var(--border-subtle)' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Supabase & Cloud Server Costs</span>
                <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--brand-primary)' }}>{fmtNaira(serverCostNaira)} ({fmtUsd(totalInfraUsd)})</span>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '0.75rem', borderBottom: '1px solid var(--border-subtle)' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Payment Gateway Fees (Monnify + Paystack)</span>
                <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--brand-orange)' }}>-{fmtNaira(totalGatewayFees)}</span>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '0.75rem', borderBottom: '1px solid var(--border-subtle)' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>SMS & WhatsApp Telemetry Alerts</span>
                <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--text-muted)' }}>-{fmtNaira(smsCharges)}</span>
              </div>
            </div>
          </div>

          {/* Net Profit Total */}
          <div style={{
            borderTop: '2px solid var(--brand-primary)',
            paddingTop: '1.5rem',
            marginTop: '1.75rem',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}>
            <div>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 700 }}>
                Estimated Net Operating Profit
              </div>
              <div style={{ fontFamily: 'var(--font-heading)', fontSize: '2rem', fontWeight: 800, color: 'var(--brand-primary)' }}>
                {fmtNaira(netProfit)}
              </div>
            </div>
            <TrendingUp size={42} color="var(--brand-primary)" />
          </div>
        </div>
      </div>
    </div>
  );
}
