#pragma once

#include "../Vector2.h"

#include <Common/Math/Vectorization/IsEquivalentTo.h>

namespace ngine::Math
{
	template<typename UnitType>
	[[nodiscard]] FORCE_INLINE PURE_NOSTATICS auto
	IsEquivalentTo(const TVector2<UnitType> a, const TVector2<UnitType> b, const UnitType epsilon = Math::NumericLimits<UnitType>::Epsilon)
	{
		return IsEquivalentTo<UnitType, 3>(a.m_vectorized, b.m_vectorized, epsilon);
	}
}
