local Services = script.Parent:WaitForChild("Services")

local order = {
	"DataService",
	"MarketService",
	"PackService",
	"GradingService",
	"StoreService",
	"OnlineService",
	"ShowService",
	"DealerService",
}

for _, name in order do
	require(Services:WaitForChild(name)).init()
end
