"""moment_windows: one row per student per day (test strategy CONT-05)

Revision ID: 0003
Revises: 0002
Create Date: 2026-11-25 22:15:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0003'
down_revision = '0002'
branch_labels = None
depends_on = None


# The table is recreated: nothing wrote to it before SCRUM-42, and its unique constraint on `day` has no name.
def upgrade() -> None:
    op.drop_table('moment_windows')
    op.create_table('moment_windows',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('student_id', sa.Integer(), nullable=False),
    sa.Column('day', sa.Date(), nullable=False),
    sa.Column('opens_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('closes_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['student_id'], ['students.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('student_id', 'day', name='uq_moment_window_student_day')
    )


def downgrade() -> None:
    op.drop_table('moment_windows')
    op.create_table('moment_windows',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('day', sa.Date(), nullable=False),
    sa.Column('opens_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('closes_at', sa.DateTime(timezone=True), nullable=False),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('day')
    )
