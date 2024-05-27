const std = @import("std");
const microzig = @import("microzig");
const lcd_driver = @import("ST7735.zig");

const rp2040 = microzig.hal;
const time = rp2040.time;
const gpio = rp2040.gpio;
const clocks = rp2040.clocks;

const uart0 = rp2040.uart.num(0);
const spi1 = rp2040.spi.num(1);

pub const microzig_options = .{
    .log_level = .debug,
    .logFn = rp2040.uart.log,
};

var lcd = lcd_driver.ST7735{ 
    .config = lcd_driver.Config{ 
        .spi = spi1,
        .dc_pin = gpio.num(8),
        .reset_pin = gpio.num(12),
        .cs_pin = gpio.num(9),
        .bl_pin = gpio.num(13) 
    }
};

const pin_config = rp2040.pins.GlobalConfiguration{
    .GPIO13 = .{ .name = "lcd_bl", .function = .PWM6_B, .direction = .out },
};

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    @breakpoint();
    while (true) {}
}

pub fn main() !void {

    // LCD backlight
    const pins = pin_config.apply();
    pins.lcd_bl.slice().set_wrap(100);
    pins.lcd_bl.slice().set_clk_div(50, 0);
    pins.lcd_bl.slice().enable();
    pins.lcd_bl.set_level(90);

    // UART for log
    uart0.apply(.{
        .baud_rate = 9600,
        .tx_pin = gpio.num(0),
        .rx_pin = gpio.num(1),
        .clock_config = rp2040.clock_config,
    });

    rp2040.uart.init_logger(uart0);

    spi1.apply(.{ 
        .clock_config = rp2040.clock_config,
        .baud_rate = 10000 * 1000,
        .tx_pin = gpio.num(11),
        .rx_pin = null,
        .sck_pin = gpio.num(10),
        .csn_pin = null 
    });

    lcd.init_device();
    lcd.init_display();
    lcd.clear_screen();

    var i: u32 = 0;
    while (true) : (i += 1) {
        std.log.info("loop {}", .{i});
        time.sleep_ms(1000);
    }
}
