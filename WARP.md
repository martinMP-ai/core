# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Quick Start

**Initial Setup:**
```bash
# Bootstrap development environment
./script/bootstrap

# Install all development dependencies (slow)
uv pip install -r requirements_test_all.txt -r requirements.txt

# Faster install for testing specific component
uv pip install -r requirements_test.txt -r requirements.txt
```

**Essential Development Commands:**
```bash
# Run linter on all files
pre-commit run --all-files

# Quick lint & test for changed files
python script/lint_and_test.py

# Run tests for specific integration
pytest tests/components/my_integration/ --cov=homeassistant.components.my_integration --cov-report term-missing

# Type check specific integration
mypy homeassistant/components/my_integration
```

## Development Commands

### Code Quality & Linting
```bash
# Run all linters (ruff, mypy, pylint)
pre-commit run --all-files

# Run only ruff (format & lint)
pre-commit run ruff-check --all-files
pre-commit run ruff-format --all-files

# Run mypy type checking
mypy homeassistant/components/my_integration  # specific integration
mypy homeassistant/ pylint/                   # everything (slow)

# Run pylint (strict linting)
pylint homeassistant/components/my_integration --ignore-missing-annotations=y
pylint homeassistant                          # everything (very slow)
```

### Testing
```bash
# Test specific integration (recommended approach)
pytest tests/components/my_integration/ \
  --cov=homeassistant.components.my_integration \
  --cov-report term-missing \
  --durations-min=1 \
  --durations=0 \
  --numprocesses=auto

# Quick test for changed files only
pytest --timeout=10 --picked

# Update test snapshots (run tests again without flag after)
pytest tests/components/my_integration/ --snapshot-update

# Run with specific database (MariaDB/PostgreSQL)
pytest tests/components/recorder --dburl=mysql://root:password@localhost/homeassistant-test
```

### Project Validation
```bash
# Validate project structure & update generated files
python -m script.hassfest

# Update requirements files after manifest.json changes
python -m script.gen_requirements_all

# Update translations after strings.json changes
python -m script.translations develop --all
```

### Development Environment
```bash
# Run Home Assistant in development mode
python -m homeassistant --config config --debug

# Check for uncommitted changes
./script/check_dirty
```

## Architecture Overview

### Core Components
- **HomeAssistant Core** (`homeassistant/core.py`): Central event loop, state machine, service registry
- **Config Entries** (`homeassistant/config_entries.py`): Manages integration configurations and lifecycle
- **Entity Registry** (`homeassistant/helpers/entity_registry.py`): Tracks all entities and their metadata
- **Device Registry** (`homeassistant/helpers/device_registry.py`): Manages physical/logical devices

### Event System
- **State Changes**: `EVENT_STATE_CHANGED` when entity states change
- **Service Calls**: `EVENT_CALL_SERVICE` for service executions  
- **Lifecycle Events**: `EVENT_HOMEASSISTANT_START`, `EVENT_HOMEASSISTANT_STOP`
- **Custom Events**: Integrations can fire custom events via `hass.bus.fire()`

### Integration Architecture
- **Platforms**: Entity types (sensor, switch, etc.) within integrations
- **Coordinators**: Centralized data fetching using `DataUpdateCoordinator`
- **Config Flow**: UI-based configuration via `ConfigFlow` classes
- **Entity Models**: Structured data models in `models.py`

## Project Structure

```
homeassistant/
├── components/               # All integrations
│   └── my_integration/
│       ├── __init__.py      # Entry point, setup_entry()
│       ├── manifest.json    # Integration metadata
│       ├── config_flow.py   # UI configuration flow
│       ├── const.py         # Constants and configuration keys
│       ├── coordinator.py   # Data update coordinator
│       ├── entity.py        # Base entity class
│       ├── models.py        # Data models
│       ├── sensor.py        # Sensor platform
│       ├── strings.json     # UI strings and translations
│       └── services.yaml    # Service definitions
├── helpers/                 # Core helper modules
│   ├── entity.py           # Base Entity class
│   ├── entity_platform.py  # Platform management
│   ├── config_validation.py # Voluptuous schemas
│   └── update_coordinator.py # Data update patterns
├── util/                   # Utility functions
└── const.py               # Global constants

tests/
├── components/             # Integration tests
│   └── my_integration/
│       ├── conftest.py    # Test fixtures
│       ├── test_config_flow.py
│       ├── test_sensor.py
│       └── snapshots/     # Syrupy snapshots
└── common.py              # Test utilities
```

## Development Workflow

### Creating New Integrations
1. **Create directory**: `homeassistant/components/my_integration/`
2. **Required files**:
   - `manifest.json` - Integration metadata (domain, name, dependencies, etc.)
   - `__init__.py` - Main setup functions (`async_setup_entry`, `async_unload_entry`)
   - `config_flow.py` - UI configuration (required for new integrations)
   - `const.py` - Domain and configuration constants

3. **Platform files**: Create `sensor.py`, `switch.py`, etc. as needed
4. **Tests**: Create corresponding test files in `tests/components/my_integration/`

### Integration Quality Scale
Home Assistant uses a quality scale (Bronze/Silver/Gold/Platinum) with specific requirements:
- **Bronze**: Basic functionality (config flow, unique IDs, error handling)  
- **Silver**: Enhanced features (unavailability handling, parallel updates)
- **Gold**: Advanced features (device management, diagnostics, translations)
- **Platinum**: Highest quality (strict typing, async dependencies)

Check `quality_scale.yaml` in integration folder to track compliance.

### Entity Development Patterns
```python
# Use DataUpdateCoordinator for data fetching
class MyCoordinator(DataUpdateCoordinator[MyData]):
    def __init__(self, hass: HomeAssistant, client: MyClient, config_entry: ConfigEntry) -> None:
        super().__init__(
            hass,
            logger=LOGGER,
            name=DOMAIN,
            update_interval=timedelta(minutes=5),
            config_entry=config_entry,  # Pass config_entry
        )

# Base entity class with coordinator
class MyEntity(CoordinatorEntity[MyCoordinator]):
    _attr_has_entity_name = True  # Use device name + entity name
    
    def __init__(self, coordinator: MyCoordinator, device_id: str) -> None:
        super().__init__(coordinator)
        self._attr_unique_id = f"{device_id}_temperature"
        self._attr_device_info = DeviceInfo(
            identifiers={(DOMAIN, device_id)},
            name=device.name,
            manufacturer="My Company",
            model="My Device",
        )
```

## Testing Guidelines

### Test Structure
- **Fixtures**: Use `conftest.py` for shared test setup
- **Mock External APIs**: Use `aiohttp_client` mocker or mock libraries
- **Snapshots**: Use syrupy for complex state/data verification
- **Integration Setup**: Test through proper `async_setup_entry()`, not direct instantiation

### Essential Test Patterns
```python
# Fixture-based setup (preferred)
@pytest.fixture
async def init_integration(hass, mock_config_entry, mock_api):
    mock_config_entry.add_to_hass(hass)
    await hass.config_entries.async_setup(mock_config_entry.entry_id)
    
# Test entity states with snapshots
async def test_entities(hass, init_integration, snapshot):
    await snapshot_platform(hass, entity_registry, snapshot, config_entry.entry_id)

# Config flow testing
async def test_user_flow_success(hass, mock_api):
    result = await hass.config_entries.flow.async_init(
        DOMAIN, context={"source": config_entries.SOURCE_USER}
    )
    # Test form submission and validation
```

### Test Coverage Requirements
- **95%+ coverage** for all integration modules
- **100% config flow coverage** - test all paths including errors
- **Entity state verification** using snapshots
- **Device registry validation** ensuring proper device assignment

## Component Development

### Manifest.json Requirements
```json
{
  "domain": "my_integration",
  "name": "My Integration", 
  "codeowners": ["@username"],
  "documentation": "https://www.home-assistant.io/integrations/my_integration",
  "integration_type": "device",  // device, hub, service, system, helper
  "iot_class": "cloud_polling",  // connectivity method
  "requirements": ["my-library==1.0.0"],
  "config_flow": true,
  "dependencies": ["http"],
  "quality_scale": "silver"
}
```

### Config Flow Implementation
```python
class MyConfigFlow(ConfigFlow, domain=DOMAIN):
    VERSION = 1
    MINOR_VERSION = 1

    async def async_step_user(self, user_input=None):
        errors = {}
        if user_input is not None:
            try:
                # Validate connection
                await self._test_connection(user_input[CONF_HOST])
            except CannotConnect:
                errors["base"] = "cannot_connect" 
            else:
                await self.async_set_unique_id(device_id)
                self._abort_if_unique_id_configured()
                return self.async_create_entry(title="My Device", data=user_input)

        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema({
                vol.Required(CONF_HOST): str,
                vol.Optional(CONF_PORT, default=80): int,
            }),
            errors=errors,
        )
```

### Service Registration
```python
# Register services in async_setup, not async_setup_entry
async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    async def handle_my_service(call: ServiceCall) -> ServiceResponse:
        # Validate config entry exists and is loaded
        if not (entry := hass.config_entries.async_get_entry(call.data[ATTR_CONFIG_ENTRY_ID])):
            raise ServiceValidationError("Entry not found")
        if entry.state is not ConfigEntryState.LOADED:
            raise ServiceValidationError("Entry not loaded")
        
        # Process service call
        return {"result": "success"}
    
    hass.services.async_register(DOMAIN, "my_service", handle_my_service)
```

## Debugging Tips

### Common Issues
- **Import Errors**: Check `requirements_all.txt` is updated after manifest changes
- **Entity Not Appearing**: Verify `unique_id`, `has_entity_name`, and device info
- **Config Flow Issues**: Check `strings.json` entries and error handling
- **Test Failures**: Use `pytest --pdb` for debugging, check mock setup

### Development Commands for Debugging
```bash
# Run with debug logging
python -m homeassistant --config config --debug --log-file debug.log

# Check integration loading
python -m script.hassfest --integration-path homeassistant/components/my_integration

# Validate specific requirements
python -m script.gen_requirements_all --integration my_integration

# Test specific integration with verbose output  
pytest tests/components/my_integration -vv --tb=short
```

### Quality Scale Debugging
Check integration's `quality_scale.yaml` status and ensure all required rules are implemented or exempted with valid reasons.

### Performance Monitoring
- Use `PARALLEL_UPDATES = 1` to serialize updates for rate-limited devices
- Implement proper `available` property for offline devices
- Use coordinator pattern to avoid redundant API calls
- Set appropriate `update_interval` based on device capabilities

## Key Development Principles

1. **Async First**: All external I/O must be async, use `async_add_executor_job` for blocking calls
2. **Error Handling**: Use specific exceptions (`ConfigEntryNotReady`, `ConfigEntryAuthFailed`, etc.)
3. **User Experience**: Provide clear error messages and validation in config flows
4. **Resource Management**: Register cleanup with `entry.async_on_unload()`
5. **Type Safety**: Use proper type hints, especially for Platinum quality scale
6. **Translation**: Use `translation_key` and `strings.json` for user-facing text
7. **Testing**: Write comprehensive tests with proper fixtures and snapshots
