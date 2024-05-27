const std = @import("std");
const microzig = @import("microzig");

const hal = microzig.hal;
const gpio = hal.gpio;
const spi = hal.spi;

pub const Config = struct {
    spi: spi.SPI,
    dc_pin: gpio.Pin,
    reset_pin: gpio.Pin,
    cs_pin: gpio.Pin,
    bl_pin: gpio.Pin
};

const TxMode = enum(u1) {
    command,
    data
};

const Command = enum(u8) { 
    nop      = 0x00,
    sw_reset = 0x01,
    slp_in   = 0x10,
    slp_out  = 0x11,
    disp_off = 0x28,
    disp_on  = 0x29,
    ca_set   = 0x2A,
    ra_set   = 0x2B,
    ram_wr   = 0x2C,
    mad_ctl  = 0x36,
    col_mode = 0x3A 
};

const ChipSelect = enum(u1) {
    select,
    unselect
};

const ColorMode = enum(u3) {
    cm12bit = 3,
    cm16bit = 5,
    cm18bit = 6
};

const SleepMode = enum(u1) {
    wakeup,
    sleep
};

const Switch = enum(u1) {
    on,
    off
};

const MemoryDataAccessControl = packed struct(u8) {
    _empty: u2 = 0,
    mh: HorizontalRefreshOrder = .left_to_right,
    rgb: ColorOrder = .rgb,
    ml: VerticalRefreshOrder = .top_to_bottom,
    mv: u1 = 0,
    mx: u1 = 0,
    my: u1 = 0,

    const HorizontalRefreshOrder = enum(u1) {
        left_to_right = 0,
        right_to_left = 1
    };

    const VerticalRefreshOrder = enum(u1) {
        top_to_bottom = 0,
        bottom_to_top = 1 
    };

    const ColorOrder = enum(u1) {
        rgb = 0,
        bgr = 1
    };
};

pub const ST7735 = struct {
    const Self = @This();
    config: Config,

    pub fn init_device(self: *Self) void {
        self.config.dc_pin.set_direction(.out);
        self.config.dc_pin.set_pull(.down);

        self.config.reset_pin.set_direction(.out);
        self.config.reset_pin.set_pull(.down);

        self.config.cs_pin.set_direction(.out);
        self.config.cs_pin.set_pull(.down);

        self.chip_select(.unselect);
    }

    fn chip_select(self: *Self, select: ChipSelect) void {
        switch (select) {
            .select => self.config.cs_pin.put(0),
            .unselect => self.config.cs_pin.put(1),
        }
    }

    fn set_tx_mode(self: *Self, mode: TxMode) void {
        switch (mode) {
            .command => self.config.dc_pin.put(0),
            .data => self.config.dc_pin.put(1),
        }
    }

    fn write_command(self: *Self, command: Command) void {
         self.set_tx_mode(.command);
         self.chip_select(.select);
         defer self.chip_select(.unselect);
         const enumAsSlice = (&@as(u8, @intFromEnum(command)))[0..1];
         _ = self.config.spi.write(enumAsSlice);
    }

    fn write_command_raw(self: *Self, cmd: u8) void {
         self.set_tx_mode(.command);
         self.chip_select(.select);
         defer self.chip_select(.unselect);
         const cmdAsSlice = [1]u8 { cmd };
         _ = spi.num(1).write(&cmdAsSlice);
    }

    fn write_data(self: *Self, data: []const u8) void {
         self.set_tx_mode(.data);
         self.chip_select(.select);
         defer self.chip_select(.unselect);
         _ = self.config.spi.write(data);
    }

    fn write_data_u8(self: *Self, data: u8) void {
        self.write_data(&[_]u8{ data });
    }

    fn write_data_u16(self: *Self, data: u16) void {
        self.write_data(&[_]u8{ @as(u8, @intCast(data >> 8)), @as(u8, @intCast(data & 0x00FF))  });
    }

    fn hardware_reset(self: *Self) void {
         self.config.reset_pin.put(1);
         hal.time.sleep_ms(200);
         self.config.reset_pin.put(0);
         hal.time.sleep_ms(200);
         self.config.reset_pin.put(1);
         hal.time.sleep_ms(200);
    }

    fn software_reset(self: *Self) void {
        self.write_command(Command.sw_reset);
        hal.time.sleep_ms(150);
    }

    fn set_sleep_mode(self: *Self, mode: SleepMode) void {
        switch (mode) {
            .wakeup => self.write_command(Command.slp_out),
            .sleep => self.write_command(Command.slp_in),
        }
        hal.time.sleep_ms(200);
    }

    fn set_color_mode(self: *Self, mode: ColorMode) void {
         self.write_command(Command.col_mode);
         const enumAsSlice = (&@as(u8, @intFromEnum(mode)))[0..1];
         self.write_data(enumAsSlice);
         hal.time.sleep_ms(10);
    }

    fn set_memory_data_access_control(self: *Self, mad: MemoryDataAccessControl) void {
         self.write_command(Command.mad_ctl);
         const structAsSlice = (&@as(u8, @bitCast(mad)))[0..1];
         self.write_data(structAsSlice);
    }

    fn set_display_switch(self: *Self, sw: Switch) void {
        switch (sw) {
            .on => self.write_command(Command.disp_on),
            .off => self.write_command(Command.disp_off),
        }
        hal.time.sleep_ms(200);
    }

    pub fn init_display(self: *Self) void {
        self.hardware_reset();

        self.write_command_raw(0x11);//Sleep exit 
        hal.time.sleep_ms(120);
        self.write_command_raw(0x21); 
        self.write_command_raw(0x21); 

        self.write_command_raw(0xB1); 
        self.write_data_u8(0x05);
        self.write_data_u8(0x3A);
        self.write_data_u8(0x3A);

        self.write_command_raw(0xB2);
        self.write_data_u8(0x05);
        self.write_data_u8(0x3A);
        self.write_data_u8(0x3A);

        self.write_command_raw(0xB3); 
        self.write_data_u8(0x05);  
        self.write_data_u8(0x3A);
        self.write_data_u8(0x3A);
        self.write_data_u8(0x05);
        self.write_data_u8(0x3A);
        self.write_data_u8(0x3A);

        self.write_command_raw(0xB4);
        self.write_data_u8(0x03);

        self.write_command_raw(0xC0);
        self.write_data_u8(0x62);
        self.write_data_u8(0x02);
        self.write_data_u8(0x04);

        self.write_command_raw(0xC1);
        self.write_data_u8(0xC0);

        self.write_command_raw(0xC2);
        self.write_data_u8(0x0D);
        self.write_data_u8(0x00);

        self.write_command_raw(0xC3);
        self.write_data_u8(0x8D);
        self.write_data_u8(0x6A);   

        self.write_command_raw(0xC4);
        self.write_data_u8(0x8D); 
        self.write_data_u8(0xEE); 

        self.write_command_raw(0xC5);
        self.write_data_u8(0x0E);    

        self.write_command_raw(0xE0);
        self.write_data_u8(0x10);
        self.write_data_u8(0x0E);
        self.write_data_u8(0x02);
        self.write_data_u8(0x03);
        self.write_data_u8(0x0E);
        self.write_data_u8(0x07);
        self.write_data_u8(0x02);
        self.write_data_u8(0x07);
        self.write_data_u8(0x0A);
        self.write_data_u8(0x12);
        self.write_data_u8(0x27);
        self.write_data_u8(0x37);
        self.write_data_u8(0x00);
        self.write_data_u8(0x0D);
        self.write_data_u8(0x0E);
        self.write_data_u8(0x10);

        self.write_command_raw(0xE1);
        self.write_data_u8(0x10);
        self.write_data_u8(0x0E);
        self.write_data_u8(0x03);
        self.write_data_u8(0x03);
        self.write_data_u8(0x0F);
        self.write_data_u8(0x06);
        self.write_data_u8(0x02);
        self.write_data_u8(0x08);
        self.write_data_u8(0x0A);
        self.write_data_u8(0x13);
        self.write_data_u8(0x26);
        self.write_data_u8(0x36);
        self.write_data_u8(0x00);
        self.write_data_u8(0x0D);
        self.write_data_u8(0x0E);
        self.write_data_u8(0x10);

        self.write_command_raw(0x3A); 
        self.write_data_u8(0x05);

        self.write_command_raw(0x36);
        self.write_data_u8(0xA8);

        self.write_command_raw(0x29);
    }

    // 10 by 10 only
    pub fn clear_screen(self: *Self) void {
        const x: u16 = 10;
        const y: u16 = 10;

        self.write_command_raw(0x2A);
        self.write_data_u16(0);
        self.write_data_u16(x);
        self.write_command_raw(0x2B);
        self.write_data_u16(0);
        self.write_data_u16(y);
        self.write_command_raw(0x2C);

        const color: u16 = 0xffff;

        var counter: u16 = x * y;
        while (counter > 0) {
            self.write_data_u16(color);
            counter -= 1;
        }
    }

};
