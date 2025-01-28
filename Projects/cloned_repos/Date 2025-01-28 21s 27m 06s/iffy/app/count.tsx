"use client";

import NumberFlow, { continuous } from "@number-flow/react";
import { useEffect, useState } from "react";

const getTotal = (count: number, countAt: Date, ratePerHour: number) =>
  Math.floor(count + ((new Date().getTime() - countAt.getTime()) / 1000 / 60 / 60) * ratePerHour);

export function Count({ count, countAt, ratePerHour }: { count: number; countAt: Date; ratePerHour: number }) {
  const [total, setTotal] = useState(getTotal(count, countAt, ratePerHour));

  useEffect(() => {
    const interval = setInterval(() => {
      setTotal(getTotal(count, countAt, ratePerHour));
    }, 1000);
    return () => clearInterval(interval);
  }, [count, countAt, ratePerHour]);

  return <NumberFlow value={total} locales="en-US" plugins={[continuous]} willChange />;
}
