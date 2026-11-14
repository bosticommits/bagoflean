--!strict
-- Which TouchControlsEnabled value UiKit should treat as "the original" when its first hold starts.
-- While the loading screen is up it has set the controls to false itself and stored the real value in
-- the "LoadingTouchSaved" player attribute; saving that false would lose the controls for the session.
local TouchHold = {}

function TouchHold.original(current: boolean, loadingActive: boolean, loadingSaved: boolean?): boolean
	if loadingActive and loadingSaved ~= nil then
		return loadingSaved
	end
	return current
end

return TouchHold
