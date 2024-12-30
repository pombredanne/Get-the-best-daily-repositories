#pragma once

#include <Common/Serialization/ForwardDeclarations/Reader.h>
#include <Common/Serialization/ForwardDeclarations/Writer.h>
#include <Common/Memory/Containers/ForwardDeclarations/FlatString.h>
#include <Common/Memory/Containers/ForwardDeclarations/String.h>
#include <Common/Math/NumericLimits.h>
#include <Common/Assert/Assert.h>

#include "Duration.h"

namespace ngine::Time
{
	//! Represents a timestamp in nanoseconds since UNIX epoch (00:00:00 UTC on January 1st 1970)
	struct Timestamp
	{
		using DurationType = Durationd;

		constexpr Timestamp()
		{
		}

		static PURE_STATICS Timestamp GetCurrent();

		bool Serialize(const Serialization::Reader serializer);
		bool Serialize(Serialization::Writer serializer) const;

		[[nodiscard]] FORCE_INLINE constexpr bool IsValid() const
		{
			return m_time != 0;
		}

		[[nodiscard]] FORCE_INLINE static constexpr Timestamp FromNanoseconds(const uint64 value)
		{
			return Timestamp{value};
		}
		[[nodiscard]] FORCE_INLINE static constexpr Timestamp FromMilliseconds(const uint64 value)
		{
			return Timestamp{value * 1000000ull};
		}
		[[nodiscard]] FORCE_INLINE static constexpr Timestamp FromSeconds(const uint64 value)
		{
			return Timestamp{value * 1000000000ull};
		}
		[[nodiscard]] FORCE_INLINE constexpr uint64 GetNanoseconds() const
		{
			return m_time;
		}
		[[nodiscard]] FORCE_INLINE constexpr uint64 GetMilliseconds() const
		{
			return m_time / 1000000ull;
		}
		[[nodiscard]] FORCE_INLINE constexpr uint64 GetSeconds() const
		{
			return m_time / 1000000000ull;
		}

		[[nodiscard]] FORCE_INLINE constexpr DurationType GetDuration() const
		{
			return DurationType::FromNanoseconds(m_time);
		}

		[[nodiscard]] FORCE_INLINE constexpr bool operator>(const Timestamp other) const
		{
			return m_time > other.m_time;
		}
		[[nodiscard]] FORCE_INLINE constexpr bool operator>=(const Timestamp other) const
		{
			return m_time >= other.m_time;
		}
		[[nodiscard]] FORCE_INLINE constexpr bool operator<(const Timestamp other) const
		{
			return m_time < other.m_time;
		}
		[[nodiscard]] FORCE_INLINE constexpr bool operator<=(const Timestamp other) const
		{
			return m_time <= other.m_time;
		}
		[[nodiscard]] FORCE_INLINE constexpr bool operator!=(const Timestamp other) const
		{
			return m_time != other.m_time;
		}
		[[nodiscard]] FORCE_INLINE constexpr bool operator==(const Timestamp other) const
		{
			return m_time == other.m_time;
		}

		[[nodiscard]] FORCE_INLINE constexpr bool operator>(const DurationType duration) const
		{
			const int64 durationInNanoseconds = duration.GetNanoseconds();
			return durationInNanoseconds > 0 && m_time > (uint64)durationInNanoseconds;
		}
		[[nodiscard]] FORCE_INLINE constexpr bool operator>=(const DurationType duration) const
		{
			const int64 durationInNanoseconds = duration.GetNanoseconds();
			return durationInNanoseconds > 0 && m_time >= (uint64)durationInNanoseconds;
		}
		[[nodiscard]] FORCE_INLINE constexpr bool operator<(const DurationType duration) const
		{
			const int64 durationInNanoseconds = duration.GetNanoseconds();
			return durationInNanoseconds < 0 || m_time < (uint64)durationInNanoseconds;
		}
		[[nodiscard]] FORCE_INLINE constexpr bool operator<=(const DurationType duration) const
		{
			const int64 durationInNanoseconds = duration.GetNanoseconds();
			return durationInNanoseconds < 0 || m_time <= (uint64)durationInNanoseconds;
		}

		[[nodiscard]] FORCE_INLINE constexpr Timestamp operator-(const Timestamp other) const
		{
			return Timestamp(m_time - other.m_time);
		}
		[[nodiscard]] FORCE_INLINE constexpr Timestamp operator+(const Timestamp other) const
		{
			return Timestamp(m_time + other.m_time);
		}

		template<typename DurationUnitType>
		[[nodiscard]] FORCE_INLINE constexpr Timestamp operator+(const Duration<DurationUnitType> duration) const
		{
			return Timestamp(m_time + static_cast<int64>(duration.GetNanoseconds()));
		}

		template<typename DurationUnitType>
		FORCE_INLINE constexpr void operator+=(const Duration<DurationUnitType> duration)
		{
			m_time += static_cast<int64>(duration.GetNanoseconds());
		}

		template<typename DurationUnitType>
		[[nodiscard]] FORCE_INLINE constexpr Timestamp operator-(const Duration<DurationUnitType> duration) const
		{
			return Timestamp(m_time - static_cast<int64>(duration.GetNanoseconds()));
		}

		template<typename DurationUnitType>
		FORCE_INLINE constexpr void operator-=(const Duration<DurationUnitType> duration)
		{
			m_time -= static_cast<int64>(duration.GetNanoseconds());
		}

		[[nodiscard]] FORCE_INLINE constexpr operator DurationType() const
		{
			Assert(
				(DurationType::UnitType(m_time) >= Math::NumericLimits<DurationType::UnitType>::Min) &
				(DurationType::UnitType(m_time) <= Math::NumericLimits<DurationType::UnitType>::Max)
			);
			return DurationType::FromSeconds((DurationType::UnitType)m_time);
		}

		//! Returns a string with the timestamp in RFC3339 format
		[[nodiscard]] FlatString<40> ToString() const;
		[[nodiscard]] String Format(const ConstStringView format) const;
	protected:
		explicit constexpr Timestamp(const uint64 timeInNanoseconds)
			: m_time(timeInNanoseconds)
		{
		}
	protected:
		//! The time since epoch in nanoseconds
		uint64 m_time = 0;
	};
}
